import 'package:flutter/material.dart';

enum AlertType {
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

enum AlertUrgency { baja, media, alta, critica }

class AlertCard extends StatelessWidget {
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? dueDate;
  final AlertType type;
  final AlertUrgency urgency;
  final bool isUnread;
  final bool isReadStyle;
  final VoidCallback onTap;

  const AlertCard({
    super.key,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.dueDate,
    required this.type,
    required this.urgency,
    required this.isUnread,
    required this.onTap,
    this.isReadStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = _alertBaseColor(type);
    final icon = _alertIcon(type);
    final dueLabel = _dueDateLabel(dueDate);
    final urgencyColor = _urgencyColor(urgency);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
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
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          Text(
                            _formatTimestamp(createdAt),
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
                        message,
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
                          _buildAlertChip(_labelType(type)),
                          if (isUnread)
                            _buildAlertChip(
                              'No leída',
                              color: const Color(0xFFFFC857),
                            ),
                          _buildAlertChip(
                            'Urgencia ${_labelUrgency(urgency)}',
                            color: urgencyColor,
                          ),
                          _buildAlertChip(
                            dueLabel,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          if (_isDueSoon(dueDate))
                            _buildAlertChip(
                              'Atención esta semana',
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          if (_isExpired(dueDate))
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

  static Widget _buildAlertChip(String text, {Color? color}) {
    final resolved = color ?? Colors.white.withValues(alpha: 0.22);

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

  static Color _alertBaseColor(AlertType type) {
    switch (type) {
      case AlertType.documentoVencimiento:
      case AlertType.documentoVencido:
        return const Color(0xFFFF6B6B);
      case AlertType.solicitudCreada:
      case AlertType.solicitudActualizada:
        return const Color(0xFF4F4CE8);
      case AlertType.mantenimientoActualizado:
      case AlertType.mantenimientoProgramado:
      case AlertType.mantenimientoSugerido:
        return const Color(0xFF16C79A);
      case AlertType.sistema:
      case AlertType.otro:
        return const Color(0xFF1F9EDC);
    }
  }

  static IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.documentoVencimiento:
        return Icons.event_busy_rounded;
      case AlertType.documentoVencido:
        return Icons.warning_rounded;
      case AlertType.solicitudCreada:
        return Icons.assignment_late_rounded;
      case AlertType.solicitudActualizada:
        return Icons.assignment_turned_in_rounded;
      case AlertType.mantenimientoActualizado:
      case AlertType.mantenimientoProgramado:
      case AlertType.mantenimientoSugerido:
        return Icons.build_circle_rounded;
      case AlertType.sistema:
      case AlertType.otro:
        return Icons.info_rounded;
    }
  }

  static Color _urgencyColor(AlertUrgency urgency) {
    switch (urgency) {
      case AlertUrgency.alta:
        return const Color(0xFFFF6B6B);
      case AlertUrgency.baja:
        return const Color(0xFF7ED957);
      case AlertUrgency.media:
        return Colors.white.withValues(alpha: 0.22);
      case AlertUrgency.critica:
        return const Color(0xFFFF3B30);
    }
  }

  static String _labelType(AlertType type) {
    switch (type) {
      case AlertType.documentoVencimiento:
        return 'Documento por vencer';
      case AlertType.documentoVencido:
        return 'Documento vencido';
      case AlertType.solicitudCreada:
        return 'Solicitud pendiente';
      case AlertType.solicitudActualizada:
        return 'Solicitud actualizada';
      case AlertType.mantenimientoActualizado:
        return 'Mantenimiento actualizado';
      case AlertType.mantenimientoProgramado:
        return 'Mantenimiento programado';
      case AlertType.mantenimientoSugerido:
        return 'Mantenimiento sugerido';
      case AlertType.sistema:
        return 'Sistema';
      case AlertType.otro:
        return 'Otro';
    }
  }

  static String _labelUrgency(AlertUrgency urgency) {
    switch (urgency) {
      case AlertUrgency.alta:
        return 'Alta';
      case AlertUrgency.baja:
        return 'Baja';
      case AlertUrgency.media:
        return 'Media';
      case AlertUrgency.critica:
        return 'Crítica';
    }
  }

  static bool _isExpired(DateTime? dueDate) {
    return dueDate != null && dueDate.isBefore(DateTime.now());
  }

  static bool _isDueSoon(DateTime? dueDate) {
    if (dueDate == null) return false;
    final diff = dueDate.difference(DateTime.now());
    return !_isExpired(dueDate) && diff.inDays <= 7;
  }

  static String _dueDateLabel(DateTime? dueDate) {
    if (dueDate == null) return 'Sin fecha límite';

    final diff = dueDate.difference(DateTime.now());

    if (diff.inDays < 0) return 'Vencida ${_formatDate(dueDate)}';
    if (diff.inDays == 0) return 'Vence hoy';
    if (diff.inDays == 1) return 'Vence mañana';
    if (diff.inDays <= 7) return 'Vence en ${diff.inDays} días';

    return 'Vence el ${_formatDate(dueDate)}';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  static String _formatTimestamp(DateTime timestamp) {
    final localTime = timestamp.toLocal();
    final now = DateTime.now();

    final sameDay =
        localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;

    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');

    if (sameDay) return '$hour:$minute';

    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }
}