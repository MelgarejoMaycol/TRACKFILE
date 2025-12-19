import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MensajesWidget extends StatefulWidget {
  final String? role;
  final String? jsonPath;
  final String? userId;

  const MensajesWidget({
    super.key,
    this.role,
    this.jsonPath,
    this.userId,
  });

  @override
  State<MensajesWidget> createState() => _MensajesWidgetState();
}

class _CompanyMessage {
  final String id;
  final String title;
  final String preview;
  final DateTime timestamp;
  final int unread;
  final String category;
  final String? status;

  const _CompanyMessage({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.unread,
    required this.category,
    this.status,
  });

  factory _CompanyMessage.fromMap(Map<String, dynamic> map) {
    return _CompanyMessage(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? 'Conversación').toString(),
      preview: (map['preview'] ?? 'Sin contenido').toString(),
      timestamp: DateTime.tryParse((map['timestamp'] ?? '').toString()) ?? DateTime.now(),
      unread: int.tryParse((map['unread'] ?? '0').toString()) ?? 0,
      category: (map['category'] ?? 'general').toString(),
      status: map['status']?.toString(),
    );
  }
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
  });

  factory _AlertNotification.fromMap(Map<String, dynamic> map) {
    final DateTime? createdAt = DateTime.tryParse((map['fecha_envio'] ?? map['createdAt'] ?? '').toString());
    final DateTime? dueDate = DateTime.tryParse((map['fecha_vencimiento'] ?? map['dueDate'] ?? '').toString());
    return _AlertNotification(
      id: (map['id'] ?? map['id_notificacion'] ?? '').toString(),
      title: (map['titulo'] ?? map['title'] ?? 'Alerta').toString(),
      message: (map['mensaje'] ?? map['message'] ?? 'Sin detalles').toString(),
      createdAt: createdAt ?? DateTime.now(),
      dueDate: dueDate,
      type: _AlertTypeX.parse((map['tipo_alerta'] ?? map['type'] ?? 'OTRO').toString()),
      urgency: _AlertUrgencyX.parse((map['urgencia'] ?? map['urgency'] ?? 'MEDIA').toString()),
      pushSent: (map['push_enviado'] ?? map['pushSent'] ?? false) == true,
      emailSent: (map['email_enviado'] ?? map['emailSent'] ?? false) == true,
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

enum _AlertUrgency { baja, media, alta }

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
      default:
        return 'Otro';
    }
  }
}

class _AlertUrgencyX {
  static _AlertUrgency parse(String raw) {
    switch (raw.toUpperCase()) {
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
      default:
        return 'Media';
    }
  }
}

class _MensajesWidgetState extends State<MensajesWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _surfaceColor = Color(0xFF1B1F6B);

  bool _isLoading = true;
  late String _role;
  List<_CompanyMessage> _messages = const [];
  List<_AlertNotification> _alerts = const [];
  String _activeFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? 'Conductor').toLowerCase();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    List<_CompanyMessage> parsedMessages = [];
    List<_AlertNotification> parsedAlerts = [];
    if (widget.jsonPath != null) {
      try {
        final String jsonString = await rootBundle.loadString(widget.jsonPath!);
        final dynamic decoded = json.decode(jsonString);
        if (decoded is Map<String, dynamic>) {
          final List<dynamic>? alertsRaw = decoded['alerts'] as List<dynamic>?;
          final List<dynamic>? messagesRaw = decoded['messages'] as List<dynamic>?;
          if (alertsRaw != null) {
            parsedAlerts = alertsRaw.map((dynamic item) {
              if (item is Map<String, dynamic>) {
                return _AlertNotification.fromMap(item);
              }
              return null;
            }).whereType<_AlertNotification>().toList();
          }
          if (messagesRaw != null) {
            parsedMessages = messagesRaw.map((dynamic item) {
              if (item is Map<String, dynamic>) {
                return _CompanyMessage.fromMap(item);
              }
              return null;
            }).whereType<_CompanyMessage>().toList();
          }
        }
      } catch (e) {
        debugPrint('Error cargando mensajes: $e');
      }
    }

    if (parsedAlerts.isEmpty) {
      parsedAlerts = _exampleAlerts();
    }
    if (parsedMessages.isEmpty) {
      parsedMessages = _exampleMessages();
    }

    parsedAlerts.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    parsedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _alerts = parsedAlerts;
        _messages = parsedMessages;
        _isLoading = false;
      });
    }
  }

  List<_CompanyMessage> _exampleMessages() {
    final DateTime now = DateTime.now();
    return [
      _CompanyMessage(
        id: '1',
        title: 'Coordinador Operativo',
        preview: 'Recuerda reportar el estado del vehículo antes de las 6 pm.',
        timestamp: now.subtract(const Duration(minutes: 12)),
        unread: 2,
        category: 'importante',
        status: 'Pendiente',
      ),
      _CompanyMessage(
        id: '2',
        title: 'Mantenimiento Taller Norte',
        preview: 'Se confirmó la cita para el mantenimiento preventivo.',
        timestamp: now.subtract(const Duration(hours: 3)),
        unread: 0,
        category: 'servicio',
        status: 'Programado',
      ),
      _CompanyMessage(
        id: '3',
        title: 'Seguridad en ruta',
        preview: 'Nueva guía de seguridad disponible para lectura.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        unread: 1,
        category: 'informativo',
        status: null,
      ),
      _CompanyMessage(
        id: '4',
        title: 'Administración Empresa',
        preview: 'Tu liquidación semanal ya está disponible.',
        timestamp: now.subtract(const Duration(days: 2, hours: 5)),
        unread: 0,
        category: 'pagos',
        status: 'Liquidadas',
      ),
    ];
  }

  List<_AlertNotification> _exampleAlerts() {
    final DateTime now = DateTime.now();
    return [
      _AlertNotification(
        id: '101',
        title: 'SOAT camión ABC-123',
        message: 'El seguro obligatorio vence pronto. Renueva antes de la fecha límite.',
        createdAt: now.subtract(const Duration(hours: 6)),
        dueDate: now.add(const Duration(days: 3)),
        type: _AlertType.vencimiento,
        urgency: _AlertUrgency.alta,
        pushSent: true,
        emailSent: false,
      ),
      _AlertNotification(
        id: '102',
        title: 'Mantenimiento preventivo',
        message: 'Agenda el mantenimiento del vehículo JKL-456 para evitar novedades.',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        dueDate: now.add(const Duration(days: 10)),
        type: _AlertType.mantenimiento,
        urgency: _AlertUrgency.media,
        pushSent: false,
        emailSent: false,
      ),
      _AlertNotification(
        id: '103',
        title: 'Recordatorio capacitación',
        message: 'Sesión virtual de seguridad vial este viernes a las 8 a.m.',
        createdAt: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 1)),
        type: _AlertType.recordatorio,
        urgency: _AlertUrgency.media,
        pushSent: true,
        emailSent: true,
      ),
    ];
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
      default:
        return _conductorMensajes();
    }
  }

  Widget _conductorMensajes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;
        final List<_CompanyMessage> filtered = _applyFilter(_messages);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: 24),
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
                'Consulta las alertas automáticas y los mensajes emitidos por tu empresa.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(isCompact: isCompact),
              const SizedBox(height: 24),
              _buildAlertsSection(isCompact: isCompact),
              const SizedBox(height: 28),
              Text(
                'Mensajes de la empresa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recordatorios, coordinaciones y novedades internas.',
                style: TextStyle(color: Colors.white60, fontSize: isCompact ? 11 : 12),
              ),
              const SizedBox(height: 18),
              _buildFilterRow(isCompact: isCompact),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _buildMessageCard(filtered[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_CompanyMessage> _applyFilter(List<_CompanyMessage> source) {
    if (_activeFilter == 'todos') {
      return source;
    }
    return source.where((thread) => thread.category == _activeFilter).toList();
  }

  Widget _buildSummaryRow({required bool isCompact}) {
    final int totalAlerts = _alerts.length;
    final int urgentAlerts = _alerts.where((alert) => alert.urgency == _AlertUrgency.alta).length;
    final int totalUnread = _messages.fold<int>(0, (prev, item) => prev + item.unread);
    final _CompanyMessage? latest = _messages.isNotEmpty ? _messages.first : null;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          label: 'Alertas activas',
          value: '$totalAlerts',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFFFC857),
        ),
        _buildSummaryCard(
          label: 'Alertas urgentes',
          value: '$urgentAlerts',
          icon: Icons.report_rounded,
          color: const Color(0xFFFF6B6B),
        ),
        _buildSummaryCard(
          label: 'Mensajes sin leer',
          value: '$totalUnread',
          icon: Icons.mark_email_unread_rounded,
          color: const Color(0xFF4F4CE8),
        ),
        _buildSummaryCard(
          label: 'Último mensaje',
          value: latest != null ? _formatTimestamp(latest.timestamp) : 'Sin actividad',
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
        color: Colors.white.withOpacity(0.08),
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
              color: color.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
          style: TextStyle(color: Colors.white60, fontSize: isCompact ? 11 : 12),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alerts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
          style: TextStyle(color: Colors.white, fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'No hay alertas activas en este momento.',
          style: TextStyle(color: Colors.white60, fontSize: isCompact ? 11 : 12),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white38, size: 40),
              const SizedBox(height: 10),
              Text(
                'Todo en orden. Sin alertas activas.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor.withOpacity(0.92), baseColor.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(alert.createdAt),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.message,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _buildAlertChip(_AlertTypeX.label(alert.type)),
              _buildAlertChip('Urgencia ${_AlertUrgencyX.label(alert.urgency)}', color: urgencyColor),
              _buildAlertChip(dueLabel, color: Colors.white.withOpacity(0.25)),
              if (alert.isDueSoon)
                _buildAlertChip('Atención esta semana', color: Colors.white.withOpacity(0.35)),
              if (alert.isExpired)
                _buildAlertChip('Vencida', color: const Color(0xFFFF6B6B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertChip(String text, {Color? color}) {
    final Color resolved = color ?? Colors.white.withOpacity(0.22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
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
      default:
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
      default:
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
      default:
        return Colors.white.withOpacity(0.22);
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

  Widget _buildFilterRow({required bool isCompact}) {
    final List<String> filters = ['todos', 'importante', 'servicio', 'informativo', 'pagos'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final String filter = filters[index];
          final bool isActive = _activeFilter == filter;
          return ChoiceChip(
            label: Text(filter[0].toUpperCase() + filter.substring(1)),
            selected: isActive,
            onSelected: (_) {
              setState(() {
                _activeFilter = filter;
              });
            },
            selectedColor: _accentColor,
            backgroundColor: _accentColor.withOpacity(0.14),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(color: isActive ? Colors.white : Colors.white24),
          );
        },
      ),
    );
  }

  Widget _buildMessageCard(_CompanyMessage message) {
    final bool hasUnread = message.unread > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Abrir conversación con ${message.title}'),
              backgroundColor: _accentColor,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceColor.withOpacity(0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
                alignment: Alignment.center,
                child: Text(
                  message.title.isNotEmpty ? message.title.characters.first.toUpperCase() : 'C',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.preview,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _buildTag(message.category),
                        if (message.status != null && message.status!.isNotEmpty)
                          _buildTag(message.status!, type: _TagType.status),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${message.unread}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, { _TagType type = _TagType.category }) {
    Color background;
    Color border;
    switch (type) {
      case _TagType.status:
        background = Colors.white.withOpacity(0.14);
        border = Colors.white24;
        break;
      case _TagType.category:
      default:
        background = _accentColor.withOpacity(0.16);
        border = Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: const [
          Icon(Icons.inbox_rounded, color: Colors.white38, size: 40),
          SizedBox(height: 12),
          Text('Sin mensajes en esta categoría', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _empresaMensajes() {
    return _buildComingSoon('empresa');
  }

  Widget _propietarioMensajes() {
    return _buildComingSoon('propietario');
  }

  Widget _secretariaMensajes() {
    return _buildComingSoon('secretaria');
  }

  Widget _adminMensajes() {
    return _buildComingSoon('administrador');
  }

  Widget _buildComingSoon(String roleLabel) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          'Panel de mensajes para $roleLabel en desarrollo',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    if (timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day) {
      final String hour = timestamp.hour.toString().padLeft(2, '0');
      final String minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final String day = timestamp.day.toString().padLeft(2, '0');
    final String month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

enum _TagType { category, status }
