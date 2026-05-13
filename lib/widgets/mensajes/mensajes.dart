import 'package:flutter/material.dart';

import '../../services/notificaciones_service.dart';

class MensajesWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;
  final String? userId;
  final VoidCallback? onNotificationsChanged;

  const MensajesWidget({
    super.key,
    this.role,
    this.jsonPath,
    this.userId,
    this.onNotificationsChanged,
  });

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
  final String estado;
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
    required this.estado,
    this.idUsuario,
    this.rolUsuario,
  });

  static DateTime? _parseServerDateToLocal(dynamic value) {
    if (value == null) return null;

    final String raw = value.toString().trim();
    if (raw.isEmpty) return null;

    // Si el backend manda fecha sin zona horaria, la tratamos como UTC.
    final bool hasTimezone =
        raw.endsWith('Z') || RegExp(r'([+-]\d{2}:\d{2})$').hasMatch(raw);

    final String normalized = hasTimezone ? raw : '${raw}Z';

    return DateTime.tryParse(normalized)?.toLocal();
  }

  factory _AlertNotification.fromMap(Map<String, dynamic> map) {
    final DateTime? createdAt = _parseServerDateToLocal(
      map['fechaEnvio'] ?? map['fecha_envio'] ?? map['createdAt'],
    );

    final DateTime? dueDate = _parseServerDateToLocal(
      map['fechaVencimiento'] ?? map['fecha_vencimiento'] ?? map['dueDate'],
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
      estado: (map['estado'] ?? map['status'] ?? 'ENVIADA')
          .toString()
          .toUpperCase(),
      idUsuario:
          (map['idUsuario'] ?? map['id_usuario'] ?? map['usuarioId'] ?? '')
              .toString(),
      rolUsuario: (map['rolUsuario'] ?? map['rol_usuario'] ?? map['rol'] ?? '')
          .toString()
          .toLowerCase(),
    );
  }

  bool get isExpired => dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isUnread => estado.toUpperCase() == 'ENVIADA';
  bool get isDueSoon {
    if (dueDate == null) return false;
    final Duration diff = dueDate!.difference(DateTime.now());
    return !isExpired && diff.inDays <= 7;
  }
}

enum _AlertType {
  documentoVencimiento,
  documentoVencido,
  solicitudCreada,
  solicitudActualizada,
  mantenimientoActualizado,
  mantenimientoProgramado,
  mantenimientoSugerido,
  sistema,
  otro,
}

enum _AlertUrgency { baja, media, alta, critica }

class _AlertTypeX {
  static _AlertType parse(String raw) {
    switch (raw.toUpperCase()) {
      case 'DOCUMENTO_VENCIMIENTO':
        return _AlertType.documentoVencimiento;
      case 'DOCUMENTO_VENCIDO':
        return _AlertType.documentoVencido;
      case 'SOLICITUD_CREADA':
        return _AlertType.solicitudCreada;
      case 'SOLICITUD_ACTUALIZADA':
        return _AlertType.solicitudActualizada;
      case 'MANTENIMIENTO_ACTUALIZADO':
        return _AlertType.mantenimientoActualizado;
      case 'MANTENIMIENTO_PROGRAMADO':
        return _AlertType.mantenimientoProgramado;
      case 'MANTENIMIENTO_SUGERIDO':
        return _AlertType.mantenimientoSugerido;
      case 'SISTEMA':
        return _AlertType.sistema;
      default:
        return _AlertType.otro;
    }
  }

  static String label(_AlertType type) {
    switch (type) {
      case _AlertType.documentoVencimiento:
        return 'Documento por vencer';
      case _AlertType.documentoVencido:
        return 'Documento vencido';
      case _AlertType.solicitudCreada:
        return 'Solicitud pendiente';
      case _AlertType.solicitudActualizada:
        return 'Solicitud actualizada';
      case _AlertType.mantenimientoActualizado:
        return 'Mantenimiento actualizado';
      case _AlertType.mantenimientoProgramado:
        return 'Mantenimiento programado';
      case _AlertType.mantenimientoSugerido:
        return 'Mantenimiento sugerido';
      case _AlertType.sistema:
        return 'Sistema';
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
  bool _showReadAlerts = false;

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
      widget.onNotificationsChanged?.call();
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

    final unreadAlerts = _alerts.where((a) => a.isUnread).toList();
    final readAlerts = _alerts.where((a) => !a.isUnread).toList();

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
          'Primero verás las notificaciones pendientes. Las leídas quedan guardadas en historial.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: isCompact ? 11 : 12,
          ),
        ),
        const SizedBox(height: 16),

        if (unreadAlerts.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await NotificacionesService.marcarTodasComoLeidas();
                  await _loadThreads();
                  widget.onNotificationsChanged?.call();
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

        if (unreadAlerts.isNotEmpty) ...[
          Text(
            'No leídas',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: unreadAlerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) => _buildAlertCard(unreadAlerts[index]),
          ),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'No tienes notificaciones pendientes.',
              style: TextStyle(color: Colors.white70),
            ),
          ),

        if (readAlerts.isNotEmpty) ...[
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _showReadAlerts = !_showReadAlerts;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notificaciones leídas (${readAlerts.length})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _showReadAlerts
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readAlerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) =>
                    _buildAlertCard(readAlerts[index], isReadStyle: true),
              ),
            ),
            crossFadeState: _showReadAlerts
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
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

  Widget _buildAlertCard(_AlertNotification alert, {bool isReadStyle = false}) {
    final Color baseColor = _alertBaseColor(alert.type);
    final IconData icon = _alertIcon(alert.type);
    final String dueLabel = _dueDateLabel(alert.dueDate);
    final Color urgencyColor = _urgencyColor(alert.urgency);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);

            try {
              await NotificacionesService.marcarComoLeida(alert.id);
              await _loadThreads();
              widget.onNotificationsChanged?.call();
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
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  baseColor.withValues(alpha: isReadStyle ? 0.28 : 0.95),
                  baseColor.withValues(alpha: isReadStyle ? 0.18 : 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: isReadStyle ? 0.08 : 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 38 : 46,
                  height: isMobile ? 38 : 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 4,
                        children: [
                          Text(
                            alert.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          Text(
                            _formatTimestamp(alert.createdAt),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alert.message,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 12.5 : 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAlertChip(_AlertTypeX.label(alert.type)),
                          if (alert.isUnread)
                            _buildAlertChip(
                              'No leída',
                              color: const Color(0xFFFFC857),
                            ),
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
                            _buildAlertChip(
                              'Vencida',
                              color: const Color(0xFFFF6B6B),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertChip(String text, {Color? color}) {
    final Color resolved = color ?? Colors.white.withValues(alpha: 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _alertBaseColor(_AlertType type) {
    switch (type) {
      case _AlertType.documentoVencimiento:
      case _AlertType.documentoVencido:
        return const Color(0xFFFF6B6B);

      case _AlertType.solicitudCreada:
      case _AlertType.solicitudActualizada:
        return const Color(0xFF4F4CE8);

      case _AlertType.mantenimientoActualizado:
      case _AlertType.mantenimientoProgramado:
      case _AlertType.mantenimientoSugerido:
        return const Color(0xFF16C79A);

      case _AlertType.sistema:
      case _AlertType.otro:
        return const Color(0xFF1F9EDC);
    }
  }

  IconData _alertIcon(_AlertType type) {
    switch (type) {
      case _AlertType.documentoVencimiento:
        return Icons.event_busy_rounded;
      case _AlertType.documentoVencido:
        return Icons.warning_rounded;

      case _AlertType.solicitudCreada:
        return Icons.assignment_late_rounded;
      case _AlertType.solicitudActualizada:
        return Icons.assignment_turned_in_rounded;

      case _AlertType.mantenimientoActualizado:
      case _AlertType.mantenimientoProgramado:
      case _AlertType.mantenimientoSugerido:
        return Icons.build_circle_rounded;

      case _AlertType.sistema:
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
    final DateTime localTime = timestamp.toLocal();
    final DateTime now = DateTime.now();

    final Duration diff = now.difference(localTime);

    final String hour = localTime.hour.toString().padLeft(2, '0');
    final String minute = localTime.minute.toString().padLeft(2, '0');

    // Hoy -> solo hora
    final bool sameDay =
        localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;

    if (sameDay || (diff.inHours < 24 && !diff.isNegative)) {
      return '$hour:$minute';
    }

    // Más de un día -> fecha + hora
    final String day = localTime.day.toString().padLeft(2, '0');
    final String month = localTime.month.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }
}
