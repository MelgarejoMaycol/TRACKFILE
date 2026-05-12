import 'package:flutter/material.dart';

import '../../services/notificaciones_service.dart';

class MensajesWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;
  final String? userId;

  const MensajesWidget({super.key, this.role, this.jsonPath, this.userId});

  @override
  State<MensajesWidget> createState() => _MensajesWidgetState();
}

class _AlertNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? dueDate;
  final _AlertType type;
  final _AlertUrgency urgency;
  final bool pushSent;
  final bool emailSent;
  final String? idUsuario;
  final String? rolUsuario;

  const _AlertNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.dueDate,
    required this.type,
    required this.urgency,
    required this.pushSent,
    required this.emailSent,
    this.idUsuario,
    this.rolUsuario,
  });

  factory _AlertNotification.fromMap(Map<String, dynamic> map) {
    final DateTime? createdAt = DateTime.tryParse(
      (map['fechaEnvio'] ?? map['fecha_envio'] ?? map['createdAt'] ?? '')
          .toString(),
    );

    final DateTime? dueDate = DateTime.tryParse(
      (map['fechaVencimiento'] ??
              map['fecha_vencimiento'] ??
              map['dueDate'] ??
              '')
          .toString(),
    );

    return _AlertNotification(
      id: (map['idNotificacion'] ?? map['id_notificacion'] ?? map['id'] ?? '')
          .toString(),
      title: (map['titulo'] ?? map['title'] ?? 'Notificación').toString(),
      message: (map['mensaje'] ?? map['message'] ?? 'Sin detalles').toString(),
      createdAt: createdAt ?? DateTime.now(),
      dueDate: dueDate,
      type: _AlertTypeX.parse(
        (map['tipoAlerta'] ?? map['tipo_alerta'] ?? map['type'] ?? 'SISTEMA')
            .toString(),
      ),
      urgency: _AlertUrgencyX.parse(
        (map['urgencia'] ?? map['urgency'] ?? 'MEDIA').toString(),
      ),
      pushSent: (map['pushEnviado'] ?? map['push_enviado'] ?? false) == true,
      emailSent: (map['emailEnviado'] ?? map['email_enviado'] ?? false) == true,
      idUsuario:
          (map['idUsuario'] ?? map['id_usuario'] ?? map['usuarioId'] ?? '')
              .toString(),
      rolUsuario: (map['rolUsuario'] ?? map['rol_usuario'] ?? map['rol'] ?? '')
          .toString()
          .toLowerCase(),
    );
  }

  bool get isExpired => dueDate != null && dueDate!.isBefore(DateTime.now());

  bool get isDueSoon {
    if (dueDate == null) return false;
    final Duration diff = dueDate!.difference(DateTime.now());
    return !isExpired && diff.inDays <= 7;
  }
}

enum _AlertType { vencimiento, mantenimiento, recordatorio, otro }

enum _AlertUrgency { baja, media, alta, critica }

class _AlertTypeX {
  static _AlertType parse(String raw) {
    switch (raw.toUpperCase()) {
      case 'VENCIMIENTO':
        return _AlertType.vencimiento;
      case 'MANTENIMIENTO':
        return _AlertType.mantenimiento;
      case 'RECORDATORIO':
        return _AlertType.recordatorio;
      default:
        return _AlertType.otro;
    }
  }

  static String label(_AlertType type) {
    switch (type) {
      case _AlertType.vencimiento:
        return 'Vencimiento';
      case _AlertType.mantenimiento:
        return 'Mantenimiento';
      case _AlertType.recordatorio:
        return 'Recordatorio';
      case _AlertType.otro:
        return 'Otro';
    }
  }
}

class _AlertUrgencyX {
  static _AlertUrgency parse(String raw) {
    switch (raw.toUpperCase()) {
      case 'CRITICA':
        return _AlertUrgency.critica;
      case 'ALTA':
        return _AlertUrgency.alta;
      case 'BAJA':
        return _AlertUrgency.baja;
      case 'MEDIA':
      default:
        return _AlertUrgency.media;
    }
  }

  static String label(_AlertUrgency urgency) {
    switch (urgency) {
      case _AlertUrgency.alta:
        return 'Alta';
      case _AlertUrgency.baja:
        return 'Baja';
      case _AlertUrgency.media:
        return 'Media';
      case _AlertUrgency.critica:
        return 'Crítica';
    }
  }
}

class _MensajesWidgetState extends State<MensajesWidget> {
  bool _isLoading = true;
  late String _role;
  List<_AlertNotification> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    try {
      final data = await NotificacionesService.listar();

      final parsedAlerts = data
          .map((item) => _AlertNotification.fromMap(item))
          .toList();

      final filteredAlerts = _filtrarPorRol(parsedAlerts);

      filteredAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      setState(() {
        _alerts = filteredAlerts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando notificaciones: $e');

      if (!mounted) return;

      setState(() {
        _alerts = const [];
        _isLoading = false;
      });
    }
  }

  List<_AlertNotification> _filtrarPorRol(List<_AlertNotification> lista) {
    final String rol = _role.toLowerCase();
    final String? userId = widget.userId?.toString();

    if (rol == 'empresa' || rol == 'admin') {
      return lista;
    }

    if (userId == null || userId.isEmpty) {
      return lista;
    }

    return lista.where((alerta) {
      return alerta.idUsuario == userId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_role) {
      case 'empresa':
        return _empresaMensajes();
      case 'propietario':
        return _propietarioMensajes();
      case 'secretaria':
        return _secretariaMensajes();
      case 'admin':
        return _adminMensajes();
      case 'conductor':
        return _conductorMensajes();
    }
    return _conductorMensajes();
  }

  Widget _conductorMensajes() {
    return _buildMensajesGeneral('Conductor');
  }

  Widget _buildSummaryRow({required bool isCompact}) {
    final int totalAlerts = _alerts.length;
    final int urgentAlerts = _alerts
        .where(
          (alert) =>
              alert.urgency == _AlertUrgency.alta ||
              alert.urgency == _AlertUrgency.critica,
        )
        .length;

    final _AlertNotification? latest = _alerts.isNotEmpty
        ? _alerts.first
        : null;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          label: 'Notificaciones',
          value: '$totalAlerts',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFFFC857),
        ),
        _buildSummaryCard(
          label: 'Urgentes',
          value: '$urgentAlerts',
          icon: Icons.report_rounded,
          color: const Color(0xFFFF6B6B),
        ),
        _buildSummaryCard(
          label: 'Última alerta',
          value: latest != null
              ? _formatTimestamp(latest.createdAt)
              : 'Sin actividad',
          icon: Icons.schedule_rounded,
          color: const Color(0xFF16C79A),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection({required bool isCompact}) {
    if (_alerts.isEmpty) {
      return _buildAlertsEmptyState(isCompact: isCompact);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alertas emitidas',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Revisa vencimientos y mantenimientos con prioridad.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: isCompact ? 11 : 12,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);

              try {
                await NotificacionesService.marcarTodasComoLeidas();
                await _loadThreads();
              } catch (e) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No se pudieron marcar todas como leídas'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            label: const Text(
              'Marcar todas como leídas',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alerts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, index) => _buildAlertCard(_alerts[index]),
        ),
      ],
    );
  }

  Widget _buildAlertsEmptyState({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alertas emitidas',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'No hay alertas activas en este momento.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: isCompact ? 11 : 12,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: Colors.white38,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Todo en orden. Sin alertas activas.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(_AlertNotification alert) {
    final Color baseColor = _alertBaseColor(alert.type);
    final IconData icon = _alertIcon(alert.type);
    final String dueLabel = _dueDateLabel(alert.dueDate);
    final Color urgencyColor = _urgencyColor(alert.urgency);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);

        try {
          await NotificacionesService.marcarComoLeida(alert.id);
          await _loadThreads();
        } catch (e) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No se pudo marcar la notificación como leída'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withValues(alpha: 0.92),
              baseColor.withValues(alpha: 0.65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatTimestamp(alert.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              alert.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 3,
              runSpacing: 1,
              children: [
                _buildAlertChip(_AlertTypeX.label(alert.type)),
                _buildAlertChip(
                  'Urgencia ${_AlertUrgencyX.label(alert.urgency)}',
                  color: urgencyColor,
                ),
                _buildAlertChip(
                  dueLabel,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                if (alert.isDueSoon)
                  _buildAlertChip(
                    'Atención esta semana',
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                if (alert.isExpired)
                  _buildAlertChip('Vencida', color: const Color(0xFFFF6B6B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertChip(String text, {Color? color}) {
    final Color resolved = color ?? Colors.white.withValues(alpha: 0.22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _alertBaseColor(_AlertType type) {
    switch (type) {
      case _AlertType.vencimiento:
        return const Color(0xFFFF6B6B);
      case _AlertType.mantenimiento:
        return const Color(0xFF4F4CE8);
      case _AlertType.recordatorio:
        return const Color(0xFF16C79A);
      case _AlertType.otro:
        return const Color(0xFF1F9EDC);
    }
  }

  IconData _alertIcon(_AlertType type) {
    switch (type) {
      case _AlertType.vencimiento:
        return Icons.event_busy_rounded;
      case _AlertType.mantenimiento:
        return Icons.build_circle_rounded;
      case _AlertType.recordatorio:
        return Icons.notifications_active_rounded;
      case _AlertType.otro:
        return Icons.info_rounded;
    }
  }

  Color _urgencyColor(_AlertUrgency urgency) {
    switch (urgency) {
      case _AlertUrgency.alta:
        return const Color(0xFFFF6B6B);
      case _AlertUrgency.baja:
        return const Color(0xFF7ED957);
      case _AlertUrgency.media:
        return Colors.white.withValues(alpha: 0.22);
      case _AlertUrgency.critica:
        return const Color(0xFFFF3B30);
    }
  }

  String _dueDateLabel(DateTime? dueDate) {
    if (dueDate == null) {
      return 'Sin fecha límite';
    }
    final DateTime now = DateTime.now();
    final Duration diff = dueDate.difference(now);
    if (diff.inDays < 0) {
      return 'Vencida ${_formatDate(dueDate)}';
    }
    if (diff.inDays == 0) {
      return 'Vence hoy';
    }
    if (diff.inDays == 1) {
      return 'Vence mañana';
    }
    if (diff.inDays <= 7) {
      return 'Vence en ${diff.inDays} días';
    }
    return 'Vence el ${_formatDate(dueDate)}';
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Widget _empresaMensajes() {
    return _buildMensajesGeneral('Empresa');
  }

  Widget _propietarioMensajes() {
    return _buildMensajesGeneral('Empresa');
  }

  Widget _secretariaMensajes() {
    return _buildMensajesGeneral('Secretaria');
  }

  Widget _adminMensajes() {
    return _buildMensajesGeneral('Administrador');
  }

  Widget _buildMensajesGeneral(String roleLabel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de notificaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                roleLabel == 'Empresa'
                    ? 'Consulta las alertas generadas para los usuarios de tu empresa.'
                    : 'Consulta tus alertas personales y vencimientos importantes.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(isCompact: isCompact),
              const SizedBox(height: 24),
              _buildAlertsSection(isCompact: isCompact),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    if (timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day) {
      final String hour = timestamp.hour.toString().padLeft(2, '0');
      final String minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final String day = timestamp.day.toString().padLeft(2, '0');
    final String month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}
