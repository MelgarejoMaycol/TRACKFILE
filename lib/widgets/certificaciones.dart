import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CertificacionesWidget extends StatefulWidget {
  final String role;
  final String? userId;
  final String? jsonPath;

  const CertificacionesWidget({
    super.key,
    required this.role,
    this.userId,
    this.jsonPath,
  });

  @override
  State<CertificacionesWidget> createState() => _CertificacionesWidgetState();
}

class _TipoSolicitud {
  final int id;
  final String nombre;
  final String descripcion;

  const _TipoSolicitud({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  factory _TipoSolicitud.fromMap(Map<String, dynamic> map) {
    return _TipoSolicitud(
      id: int.tryParse(map['id_tipo_solicitud']?.toString() ?? '') ?? 0,
      nombre: map['nombre']?.toString() ?? 'Tipo sin nombre',
      descripcion: map['descripcion']?.toString() ?? '',
    );
  }
}

class _Solicitud {
  final int id;
  final String idUsuario;
  final int idTipo;
  final String descripcion;
  final String estado;
  final DateTime? fechaEnvio;
  final String? urlDocumento;
  final int? idDocumento;
  final int? idVehiculo;

  const _Solicitud({
    required this.id,
    required this.idUsuario,
    required this.idTipo,
    required this.descripcion,
    required this.estado,
    required this.fechaEnvio,
    required this.urlDocumento,
    required this.idDocumento,
    required this.idVehiculo,
  });

  factory _Solicitud.fromMap(Map<String, dynamic> map) {
    final DateTime? fecha = DateTime.tryParse(map['fecha_envio']?.toString() ?? '');
    final int? documento = map['id_documento'] == null
        ? null
        : int.tryParse(map['id_documento'].toString());
    final int? vehiculo = map['id_vehiculo'] == null
        ? null
        : int.tryParse(map['id_vehiculo'].toString());
    return _Solicitud(
      id: int.tryParse(map['id_solicitud']?.toString() ?? '') ?? 0,
      idUsuario: map['id_usuario']?.toString() ?? '',
      idTipo: int.tryParse(map['id_tipo_solicitud']?.toString() ?? '') ?? 0,
      descripcion: map['descripcion']?.toString() ?? 'Sin descripcion',
      estado: map['estado']?.toString() ?? 'EN_REVISION',
      fechaEnvio: fecha,
      urlDocumento: map['url_documento']?.toString(),
      idDocumento: documento,
      idVehiculo: vehiculo,
    );
  }
}

class _Historial {
  final int id;
  final int idSolicitud;
  final String accion;
  final DateTime? fecha;
  final String observaciones;

  const _Historial({
    required this.id,
    required this.idSolicitud,
    required this.accion,
    required this.fecha,
    required this.observaciones,
  });

  factory _Historial.fromMap(Map<String, dynamic> map) {
    final DateTime? fecha = DateTime.tryParse(map['fecha']?.toString() ?? '');
    return _Historial(
      id: int.tryParse(map['id_historial']?.toString() ?? '') ?? 0,
      idSolicitud: int.tryParse(map['id_solicitud']?.toString() ?? '') ?? 0,
      accion: map['accion']?.toString() ?? 'EN_REVISION',
      fecha: fecha,
      observaciones: map['observaciones']?.toString() ?? '',
    );
  }
}

class _SolicitudDetalle {
  final _Solicitud solicitud;
  final _TipoSolicitud? tipo;
  final List<_Historial> historial;

  const _SolicitudDetalle({
    required this.solicitud,
    required this.tipo,
    required this.historial,
  });

  String get estadoActual => solicitud.estado.toUpperCase();

  _Historial? get ultimoMovimiento {
    if (historial.isEmpty) {
      return null;
    }
    final List<_Historial> ordered = List<_Historial>.from(historial)
      ..sort((a, b) {
        final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return ordered.first;
  }
}

class _CertificacionesWidgetState extends State<CertificacionesWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _surfaceColor = Color(0xFF131741);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);
  static const Color _infoColor = Color(0xFF3DA9F5);

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  late final String _roleNormalized;

  bool _isLoading = true;
  bool _hasError = false;
  List<_SolicitudDetalle> _detalles = const [];
  Map<String, int> _conteoEstados = const {};
  Map<int, _SolicitudDetalle> _detallesPorId = const {};
  List<_SolicitudDetalle> _todosDetalles = const [];

  bool get _isConductor => _roleNormalized == 'conductor';

  @override
  void initState() {
    super.initState();
    _roleNormalized = widget.role.toLowerCase();
    _loadData();
  }

  Future<void> _loadData() async {
    final String path = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/certificaciones_data.json';

    try {
      final String raw = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Formato inesperado');
      }

      final List<_TipoSolicitud> tipos = (decoded['tipo_solicitud'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_TipoSolicitud.fromMap)
          .toList();
      final Map<int, _TipoSolicitud> tiposById = {
        for (final _TipoSolicitud tipo in tipos) tipo.id: tipo,
      };

      final List<_Solicitud> solicitudes = (decoded['solicitudes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_Solicitud.fromMap)
          .toList();

      final List<_Historial> historial = (decoded['historial_solicitudes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_Historial.fromMap)
          .toList();

      final Map<int, List<_Historial>> historialPorSolicitud = <int, List<_Historial>>{};
      for (final _Historial registro in historial) {
        historialPorSolicitud.putIfAbsent(registro.idSolicitud, () => <_Historial>[]).add(registro);
      }

      final List<_SolicitudDetalle> todosDetalles = solicitudes.map((solicitud) {
        final _TipoSolicitud? tipo = tiposById[solicitud.idTipo];
        final List<_Historial> hist = historialPorSolicitud[solicitud.id] ?? const [];
        return _SolicitudDetalle(solicitud: solicitud, tipo: tipo, historial: hist);
      }).toList();

      final List<_SolicitudDetalle> detallesSeleccionados = _selectDetallesForRole(todosDetalles);

      if (!mounted) {
        return;
      }

      setState(() {
        _todosDetalles = todosDetalles;
        _assignDetalles(detallesSeleccionados);
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error cargando certificaciones: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_detalles.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 640;
        final bool isTableCompact = width < 960;
        return _buildRoleContent(isCompact, isTableCompact);
      },
    );
  }

  Widget _buildRoleContent(bool isCompact, bool isTableCompact) {
    switch (_roleNormalized) {
      case 'propietario':
        return _buildCommonLayout(
          isCompact: isCompact,
          title: 'Historial de certificaciones',
          subtitle: 'Controla el estado de las solicitudes vinculadas a tus vehiculos.',
          tableDetalles: _detalles,
          tableCompact: isTableCompact,
        );
      case 'empresa':
      case 'admin':
      case 'secretaria':
        return _buildCommonLayout(
          isCompact: isCompact,
          title: 'Panel de certificaciones',
          subtitle: 'Visualiza y gestiona las solicitudes enviadas por los conductores.',
          tableDetalles: _detalles,
          tableCompact: isTableCompact,
        );
      default:
        final List<_SolicitudDetalle> aprobadas = _detalles
            .where((detalle) => _normalizeStatus(detalle.estadoActual).startsWith('APROB'))
            .toList();
        return _buildCommonLayout(
          isCompact: isCompact,
          title: 'Estado de certificaciones',
          subtitle: 'Seguimiento de las solicitudes que realiza el conductor (certificado laboral, antecedentes y mas).',
          tableDetalles: aprobadas,
          tableCompact: isTableCompact,
          tableTitle: 'Historial de certificados aprobados',
          tableEmptyMessage: 'Aun no tienes certificaciones aprobadas.',
        );
    }
  }

  Widget _buildCommonLayout({
    required bool isCompact,
    required String title,
    required String subtitle,
    required List<_SolicitudDetalle>? tableDetalles,
    required bool tableCompact,
    String? tableTitle,
    String? tableEmptyMessage,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        24,
        isCompact ? 16 : 24,
        isCompact ? 120 : 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact
                ? 760
                : tableCompact
                    ? 900
                    : 1100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          if (isCompact) ...[
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _buildSummaryChips(isCompact),
          const SizedBox(height: 20),
          if (_hasHistorial) ...[
            _buildRecentActivity(isCompact),
            const SizedBox(height: 20),
          ],
          if (tableDetalles != null) ...[
            if (tableTitle != null) ...[
              Text(
                tableTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
            ],
                if (tableDetalles.isNotEmpty)
                  _buildSolicitudesView(tableDetalles, tableCompact)
                else
              _buildEmptyTable(tableEmptyMessage ?? 'No hay solicitudes registradas.'),
          ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryChips(bool isCompact) {
    final List<MapEntry<String, int>> orderedEntries = _conteoEstados.entries.toList()
      ..sort((a, b) => _statusPriority(a.key).compareTo(_statusPriority(b.key)));

    final List<Widget> chips = orderedEntries.map((entry) {
      final Color color = _statusColor(entry.key);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              _statusLabel(entry.key),
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Text(
              entry.value.toString(),
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }).toList();

    return Wrap(
      spacing: 14,
      runSpacing: 12,
      children: chips,
    );
  }

  Widget _buildSolicitudesView(List<_SolicitudDetalle> detalles, bool isCompact) {
    if (isCompact) {
      return Column(
        children: detalles
            .map((detalle) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildSolicitudCard(detalle),
                ))
            .toList(),
      );
    }
    return _buildDataTable(detalles);
  }

  Widget _buildDataTable(List<_SolicitudDetalle> detalles) {
    final List<_SolicitudDetalle> ordered = List<_SolicitudDetalle>.from(detalles)
      ..sort((a, b) => _statusPriority(a.estadoActual).compareTo(_statusPriority(b.estadoActual)));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Colors.white70),
          columnSpacing: 28,
          horizontalMargin: 18,
          dataRowMinHeight: 68,
          dataRowMaxHeight: 120,
          columns: const [
            DataColumn(label: Text('Solicitud')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Fecha envio')),
            DataColumn(label: Text('Ultima accion')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: ordered.map(_buildDataRow).toList(),
        ),
      ),
    );
  }

  Widget _buildSolicitudCard(_SolicitudDetalle detalle) {
    final _Solicitud solicitud = detalle.solicitud;
    final _TipoSolicitud? tipo = detalle.tipo;
    final _Historial? ultimo = detalle.ultimoMovimiento;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${solicitud.id} - ${solicitud.descripcion}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tipo?.nombre ?? 'Sin tipo',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _buildEstadoTag(detalle.estadoActual),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildInfoBadge(Icons.calendar_month, 'Envío: ${_formatDate(solicitud.fechaEnvio)}'),
              if (ultimo != null)
                _buildInfoBadge(Icons.update, 'Último: ${_statusLabel(ultimo.accion)}'),
              if (ultimo != null)
                _buildInfoBadge(Icons.timer, _formatDate(ultimo.fecha)),
              if (solicitud.idDocumento != null)
                _buildInfoBadge(Icons.insert_drive_file, 'Doc ${solicitud.idDocumento}'),
              if (solicitud.idVehiculo != null)
                _buildInfoBadge(Icons.directions_car_filled, 'Veh ${solicitud.idVehiculo}'),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showHistorialDetalle(detalle),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Ver historial'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(_SolicitudDetalle detalle) {
    final _Solicitud solicitud = detalle.solicitud;
    final _TipoSolicitud? tipo = detalle.tipo;
    final _Historial? ultimo = detalle.ultimoMovimiento;

    return DataRow(
      cells: [
        DataCell(_buildSolicitudCell(solicitud)),
        DataCell(Text(tipo?.nombre ?? 'Sin tipo', style: const TextStyle(color: Colors.white))),
        DataCell(_buildEstadoTag(detalle.estadoActual)),
        DataCell(Text(_formatDate(solicitud.fechaEnvio))),
        DataCell(Text(
          ultimo != null
              ? '${_statusLabel(ultimo.accion)}\n${_formatDate(ultimo.fecha)}'
              : 'Sin movimientos',
        )),
        DataCell(
          TextButton(
            onPressed: () => _showHistorialDetalle(detalle),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Ver historial'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTable(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sin resultados',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCell(_Solicitud solicitud) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#${solicitud.id} - ${solicitud.descripcion}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (solicitud.idDocumento != null)
              _buildInfoChip(Icons.insert_drive_file, 'Doc ${solicitud.idDocumento}'),
            if (solicitud.idVehiculo != null) ...[
              if (solicitud.idDocumento != null) const SizedBox(width: 8),
              _buildInfoChip(Icons.directions_car_filled, 'Veh ${solicitud.idVehiculo}'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEstadoTag(String estado) {
    final Color color = _statusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        _statusLabel(estado),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showHistorialDetalle(_SolicitudDetalle detalle) async {
    if (detalle.historial.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: _cardColor,
            title: const Text('Historial de la solicitud', style: TextStyle(color: Colors.white)),
            content: const Text('Aun no se registran movimientos para esta solicitud.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final List<_Historial> ordered = List<_Historial>.from(detalle.historial)
          ..sort((a, b) {
            final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Historial solicitud #${detalle.solicitud.id}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final _Historial registro = ordered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(registro.accion).withValues(alpha: 0.2),
                        child: Icon(Icons.check_circle, color: _statusColor(registro.accion)),
                      ),
                      title: Text(
                        _statusLabel(registro.accion),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(registro.fecha), style: const TextStyle(color: Colors.white70)),
                          if (registro.observaciones.isNotEmpty)
                            Text(registro.observaciones, style: const TextStyle(color: Colors.white60)),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(color: Colors.white24),
                  itemCount: ordered.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 40),
          const SizedBox(height: 12),
          const Text('No fue posible cargar la informacion.', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadData,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.white54, size: 48),
          const SizedBox(height: 14),
          const Text('No hay solicitudes registradas.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Cuando se cree una solicitud de certificacion aparecera aqui.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Map<String, int> _recalcularConteo(List<_SolicitudDetalle> detalles) {
    final Map<String, int> conteo = <String, int>{};
    for (final _SolicitudDetalle detalle in detalles) {
      final String key = detalle.estadoActual;
      conteo.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return conteo;
  }

  void _assignDetalles(List<_SolicitudDetalle> detalles) {
    _detalles = detalles;
    _conteoEstados = _recalcularConteo(detalles);
    _detallesPorId = {
      for (final _SolicitudDetalle detalle in detalles) detalle.solicitud.id: detalle,
    };
  }

  _SolicitudDetalle? _getDetalleById(int solicitudId) {
    final _SolicitudDetalle? directo = _detallesPorId[solicitudId];
    if (directo != null) {
      return directo;
    }
    for (final _SolicitudDetalle detalle in _todosDetalles) {
      if (detalle.solicitud.id == solicitudId) {
        return detalle;
      }
    }
    return null;
  }

  List<_SolicitudDetalle> _selectDetallesForRole(List<_SolicitudDetalle> todos) {
    if (todos.isEmpty) {
      return const [];
    }

    final String? userId = widget.userId?.trim();

    if (_isConductor) {
      final List<_SolicitudDetalle> propios = (userId != null && userId.isNotEmpty)
          ? todos.where((detalle) => detalle.solicitud.idUsuario == userId).toList()
          : <_SolicitudDetalle>[];
      if (propios.isNotEmpty) {
        return propios;
      }
      final List<_SolicitudDetalle> fallback = todos
          .where((detalle) => detalle.solicitud.idUsuario == '1')
          .toList();
      if (fallback.isNotEmpty) {
        return fallback;
      }
      return todos;
    }

    switch (_roleNormalized) {
      case 'propietario':
        final String fallbackId = (userId != null && userId.isNotEmpty) ? userId : '12';
        final List<_SolicitudDetalle> propios = todos
            .where((detalle) => detalle.solicitud.idUsuario == fallbackId)
            .toList();
        if (propios.isNotEmpty) {
          return propios;
        }
        final List<_SolicitudDetalle> fallback = todos
            .where((detalle) => detalle.solicitud.idUsuario == '12')
            .toList();
        if (fallback.isNotEmpty) {
          return fallback;
        }
        return todos;
      default:
        return todos;
    }
  }

  bool get _hasHistorial {
    for (final _SolicitudDetalle detalle in _detalles) {
      if (detalle.historial.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Widget _buildRecentActivity(bool isCompact) {
    final List<_Historial> registros = _detalles
        .expand((detalle) => detalle.historial)
        .where((hist) => hist.fecha != null)
        .toList()
      ..sort((a, b) {
        final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (registros.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<_Historial> recientes = registros.take(5).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(isCompact ? 16 : 20, 18, isCompact ? 16 : 20, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movimientos recientes',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ultimas acciones registradas en las solicitudes del conductor.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < recientes.length; i++) ...[
            _buildRecentActivityTile(recientes[i]),
            if (i != recientes.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivityTile(_Historial registro) {
    final _SolicitudDetalle? detalle = _getDetalleById(registro.idSolicitud);
    final String descripcion = detalle?.solicitud.descripcion ?? 'Solicitud #${registro.idSolicitud}';
    final String tipo = detalle?.tipo?.nombre ?? 'Tipo no identificado';
    final Color color = _statusColor(registro.accion);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMovimientoDetalle(registro),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.auto_awesome, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(registro.accion),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tipo,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (registro.observaciones.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        registro.observaciones,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(registro.fecha),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '#${registro.idSolicitud}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMovimientoDetalle(_Historial registro) async {
    final _SolicitudDetalle? detalle = _getDetalleById(registro.idSolicitud);
    final _Solicitud? solicitud = detalle?.solicitud;
    final String estadoActual = detalle?.estadoActual ?? registro.accion;
    final String tipoNombre = detalle?.tipo?.nombre ?? 'Tipo no identificado';
    final List<_Historial> historialOrdenado = detalle != null && detalle.historial.isNotEmpty
        ? List<_Historial>.from(detalle.historial)
        : <_Historial>[registro];
    historialOrdenado.sort((a, b) {
      final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final String urlDocumento = solicitud?.urlDocumento ?? '';
    final bool hasDocumento = urlDocumento.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Solicitud #${registro.idSolicitud}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tipoNombre,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _buildEstadoTag(estadoActual),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Fecha de envio', _formatDate(solicitud?.fechaEnvio)),
                _buildInfoRow('Accion mas reciente', _statusLabel(historialOrdenado.first.accion)),
                _buildInfoRow('Fecha movimiento reciente', _formatDate(historialOrdenado.first.fecha)),
                if (solicitud?.idDocumento != null)
                  _buildInfoRow('Documento asociado', 'Doc ${solicitud!.idDocumento}'),
                if (solicitud?.idVehiculo != null)
                  _buildInfoRow('Vehiculo asociado', 'Veh ${solicitud!.idVehiculo}'),
                const SizedBox(height: 20),
                Text(
                  'Movimiento seleccionado',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildInfoRow('Accion', _statusLabel(registro.accion)),
                _buildInfoRow('Fecha', _formatDate(registro.fecha)),
                if (registro.observaciones.isNotEmpty)
                  _buildInfoRow('Observaciones', registro.observaciones),
                const SizedBox(height: 20),
                Text(
                  'Historial completo',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historialOrdenado.length,
                  itemBuilder: (context, index) {
                    final _Historial elemento = historialOrdenado[index];
                    final Color itemColor = _statusColor(elemento.accion);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: itemColor.withValues(alpha: 0.18),
                            ),
                            child: Icon(Icons.history_rounded, color: itemColor, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLabel(elemento.accion),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(elemento.fecha),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                if (elemento.observaciones.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    elemento.observaciones,
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: hasDocumento ? () => _handleDownload(urlDocumento) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar certificado'),
                ),
                if (!hasDocumento) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Aun no hay un certificado disponible para descargar.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleDownload(String url) {
    debugPrint('Descargando certificado desde: $url');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando certificado...')),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return _dateFormat.format(value.toLocal());
  }

  String _normalizeStatus(String value) => value.toUpperCase();

  int _statusPriority(String value) {
    const Map<String, int> order = {
      'ENVIADA': 0,
      'EN_REVISION': 1,
      'RECHAZADA': 2,
      'RECHAZADO': 2,
      'APROBADA': 3,
      'APROBADO': 3,
    };
    return order[_normalizeStatus(value)] ?? 9;
  }

  String _statusLabel(String value) {
    final String normalized = value.toUpperCase();
    switch (normalized) {
      case 'APROBADA':
      case 'APROBADO':
        return 'Aprobada';
      case 'RECHAZADA':
      case 'RECHAZADO':
        return 'Rechazada';
      case 'EN_REVISION':
        return 'En revision';
      case 'ENVIADA':
        return 'Enviada';
      default:
        return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
    }
  }

  Color _statusColor(String value) {
    final String normalized = value.toUpperCase();
    if (normalized.startsWith('APROB')) {
      return _successColor;
    }
    if (normalized.startsWith('RECHAZ')) {
      return _dangerColor;
    }
    if (normalized.contains('REVISION')) {
      return _warningColor;
    }
    if (normalized.contains('ENVI')) {
      return _infoColor;
    }
    return _accentColor;
  }
}
