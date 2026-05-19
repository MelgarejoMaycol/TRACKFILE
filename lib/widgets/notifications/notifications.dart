import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/notificaciones_service.dart';
import '../utils/shimmer_skeleton.dart';
import 'alert_card.dart';

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
  final AlertType type;
  final AlertUrgency urgency;
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
      type: _parseAlertType(
        (map['tipoAlerta'] ?? map['tipo_alerta'] ?? map['type'] ?? 'SISTEMA')
            .toString(),
      ),
      urgency: _parseAlertUrgency(
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
  bool get isUnread {
    final value = estado.toUpperCase();
    return value == 'ENVIADA' || value == 'NO_LEIDA' || value == 'PENDIENTE';
  }

  bool get isDueSoon {
    if (dueDate == null) return false;
    final Duration diff = dueDate!.difference(DateTime.now());
    return !isExpired && diff.inDays <= 7;
  }
}

AlertType _parseAlertType(String raw) {
  switch (raw.toUpperCase()) {
    case 'DOCUMENTO_VENCIMIENTO':
      return AlertType.documentoVencimiento;
    case 'DOCUMENTO_VENCIDO':
      return AlertType.documentoVencido;
    case 'SOLICITUD_CREADA':
      return AlertType.solicitudCreada;
    case 'SOLICITUD_ACTUALIZADA':
      return AlertType.solicitudActualizada;
    case 'MANTENIMIENTO_ACTUALIZADO':
      return AlertType.mantenimientoActualizado;
    case 'MANTENIMIENTO_PROGRAMADO':
      return AlertType.mantenimientoProgramado;
    case 'MANTENIMIENTO_SUGERIDO':
      return AlertType.mantenimientoSugerido;
    case 'SISTEMA':
      return AlertType.sistema;
    default:
      return AlertType.otro;
  }
}

AlertUrgency _parseAlertUrgency(String raw) {
  switch (raw.toUpperCase()) {
    case 'CRITICA':
      return AlertUrgency.critica;
    case 'ALTA':
      return AlertUrgency.alta;
    case 'BAJA':
      return AlertUrgency.baja;
    case 'MEDIA':
    default:
      return AlertUrgency.media;
  }
}

class _MensajesWidgetState extends State<MensajesWidget> {
  bool _showReadAlerts = false;
  bool _isLoading = true;
  late String _role;
  List<_AlertNotification> _alerts = const [];
  List<_AlertNotification> get _unreadAlerts =>
      _alerts.where((a) => a.isUnread).toList();

  List<_AlertNotification> get _readAlerts =>
      _alerts.where((a) => !a.isUnread).toList();

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    try {
      final data = await NotificacionesService.listar();
      final filteredAlerts = _filtrarPorRol(
        data.map((item) => _AlertNotification.fromMap(item)).toList(),
      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      setState(() {
        _alerts = filteredAlerts;
        _isLoading = false;
      });
      widget.onNotificationsChanged?.call();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _alerts = const [];
        _isLoading = false;
      });
    }
  }

  List<_AlertNotification> _filtrarPorRol(List<_AlertNotification> lista) {
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerNotificacionesPage();
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
    final unreadAlerts = _unreadAlerts.length;
    final readAlerts = _readAlerts.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          label: 'No leídas',
          value: '$unreadAlerts',
          icon: Icons.mark_email_unread_rounded,
          color: const Color(0xFFFF6B6B),
        ),

        _buildSummaryCard(
          label: 'Leídas',
          value: '$readAlerts',
          icon: Icons.mark_email_read_rounded,
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

    final unreadAlerts = _unreadAlerts;
    final readAlerts = _readAlerts;

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
          Column(
            children: unreadAlerts
                .map((alert) => _buildAlertCard(alert))
                .toList(),
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
              child: Column(
                children: readAlerts
                    .map((alert) => _buildAlertCard(alert, isReadStyle: true))
                    .toList(),
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

  Future<void> _abrirNotificacion(_AlertNotification alert) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (alert.isUnread) {
        await NotificacionesService.marcarComoLeida(alert.id);
        await _loadThreads();
        widget.onNotificationsChanged?.call();
      }

      if (!mounted) return;

      final String role = _role.toLowerCase().isEmpty
          ? 'empresa'
          : _role.toLowerCase();

      switch (alert.type) {
        case AlertType.documentoVencimiento:
        case AlertType.documentoVencido:
          context.goNamed(
            'dashboard_section',
            pathParameters: {'role': role, 'section': 'documentos'},
          );
          break;

        case AlertType.solicitudCreada:
        case AlertType.solicitudActualizada:
          context.goNamed(
            'dashboard_section',
            pathParameters: {'role': role, 'section': 'certificaciones'},
          );
          break;

        case AlertType.mantenimientoActualizado:
        case AlertType.mantenimientoProgramado:
        case AlertType.mantenimientoSugerido:
          context.goNamed(
            'dashboard_section',
            pathParameters: {'role': role, 'section': 'mantenimientos'},
          );
          break;

        case AlertType.sistema:
          context.goNamed(
            'dashboard_section',
            pathParameters: {'role': role, 'section': 'inicio'},
          );
          break;

        case AlertType.otro:
          context.goNamed(
            'dashboard_section',
            pathParameters: {'role': role, 'section': 'perfil'},
          );
          break;
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la notificación'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildAlertCard(_AlertNotification alert, {bool isReadStyle = false}) {
    return AlertCard(
      title: alert.title,
      message: alert.message,
      createdAt: alert.createdAt,
      dueDate: alert.dueDate,
      type: alert.type,
      urgency: alert.urgency,
      isUnread: alert.isUnread,
      isReadStyle: isReadStyle,
      onTap: () => _abrirNotificacion(alert),
    );
  }

  Widget _empresaMensajes() {
    return _buildMensajesGeneral('Empresa');
  }

  Widget _propietarioMensajes() {
    return _buildMensajesGeneral('Propietario');
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
}
