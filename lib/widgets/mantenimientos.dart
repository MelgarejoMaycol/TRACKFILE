import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MantenimientosWidget extends StatefulWidget {
  final String role;
  final String? userId;
  final String? jsonPath;

  const MantenimientosWidget({
    super.key,
    required this.role,
    this.userId,
    this.jsonPath,
  });

  @override
  State<MantenimientosWidget> createState() => _MantenimientosWidgetState();
}

class _TipoMantenimiento {
  final int id;
  final String nombre;
  final String descripcion;

  const _TipoMantenimiento({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  factory _TipoMantenimiento.fromMap(Map<String, dynamic> map) {
    return _TipoMantenimiento(
      id: int.tryParse(map['id_tipo_mantenimiento']?.toString() ?? '') ?? 0,
      nombre: map['nombre']?.toString() ?? 'Tipo sin nombre',
      descripcion: map['descripcion']?.toString() ?? '',
    );
  }
}

class _Mantenimiento {
  final int id;
  final int vehiculoId;
  final String usuarioId;
  final int tipoId;
  final DateTime? fechaSugerida;
  final DateTime? fechaProgramada;
  final DateTime? fechaRealizada;
  final int kilometraje;
  final int costo;
  final String taller;
  final String estado;
  final String observaciones;

  const _Mantenimiento({
    required this.id,
    required this.vehiculoId,
    required this.usuarioId,
    required this.tipoId,
    required this.fechaSugerida,
    required this.fechaProgramada,
    required this.fechaRealizada,
    required this.kilometraje,
    required this.costo,
    required this.taller,
    required this.estado,
    required this.observaciones,
  });

  factory _Mantenimiento.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      final String raw = value?.toString() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return _Mantenimiento(
      id: int.tryParse(map['id_mantenimiento']?.toString() ?? '') ?? 0,
      vehiculoId: int.tryParse(map['id_vehiculo']?.toString() ?? '') ?? 0,
      usuarioId: map['id_usuario']?.toString() ?? '',
      tipoId: int.tryParse(map['id_tipo_mantenimiento']?.toString() ?? '') ?? 0,
      fechaSugerida: parseDate(map['fecha_sugerida']),
      fechaProgramada: parseDate(map['fecha_programada']),
      fechaRealizada: parseDate(map['fecha_realizado']),
      kilometraje: int.tryParse(map['kilometraje']?.toString() ?? '') ?? 0,
      costo: int.tryParse(map['costo']?.toString() ?? '') ?? 0,
      taller: map['taller']?.toString() ?? 'Sin taller definido',
      estado: map['estado']?.toString() ?? 'SUGERIDO',
      observaciones: map['observaciones']?.toString() ?? '',
    );
  }
}

class _HistorialMantenimiento {
  final int id;
  final int mantenimientoId;
  final String accion;
  final DateTime? fecha;
  final String comentario;

  const _HistorialMantenimiento({
    required this.id,
    required this.mantenimientoId,
    required this.accion,
    required this.fecha,
    required this.comentario,
  });

  factory _HistorialMantenimiento.fromMap(Map<String, dynamic> map) {
    final DateTime? fecha = DateTime.tryParse(map['fecha']?.toString() ?? '');
    return _HistorialMantenimiento(
      id: int.tryParse(map['id_historial']?.toString() ?? '') ?? 0,
      mantenimientoId: int.tryParse(map['id_mantenimiento']?.toString() ?? '') ?? 0,
      accion: map['accion']?.toString() ?? 'SUGERIDO',
      fecha: fecha,
      comentario: map['comentario']?.toString() ?? '',
    );
  }
}

class _MantenimientoDetalle {
  final _Mantenimiento mantenimiento;
  final _TipoMantenimiento? tipo;
  final List<_HistorialMantenimiento> historial;

  const _MantenimientoDetalle({
    required this.mantenimiento,
    required this.tipo,
    required this.historial,
  });

  String get estadoActual => mantenimiento.estado.toUpperCase();

  _HistorialMantenimiento? get ultimoMovimiento {
    if (historial.isEmpty) return null;
    final List<_HistorialMantenimiento> ordered = List<_HistorialMantenimiento>.from(historial)
      ..sort((a, b) {
        final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return ordered.first;
  }
}

class _MantenimientosWidgetState extends State<MantenimientosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _surfaceColor = Color(0xFF121738);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);
  static const Color _infoColor = Color(0xFF3DA9F5);

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  bool _hasError = false;
  List<_MantenimientoDetalle> _detalles = const [];
  List<_MantenimientoDetalle> _todosLosDetalles = const [];
  List<_MantenimientoDetalle> _programados = const [];
  Map<String, int> _conteoEstados = const {};
  Map<int, List<_HistorialMantenimiento>> _historialPorMantenimiento = const {};
  int _nextHistorialId = 1;
  bool _isFallbackData = false;

  bool get _isConductor => widget.role.toLowerCase() == 'conductor';

  bool get _isEmpresa => widget.role.toLowerCase() == 'empresa';

  bool get _shouldSplitLayout => widget.role.toLowerCase() == 'conductor' || widget.role.toLowerCase() == 'propietario';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String path = (widget.jsonPath != null && widget.jsonPath!.isNotEmpty)
        ? widget.jsonPath!
        : 'assets/mantenimientos_data.json';

    try {
      final String raw = await rootBundle.loadString(path);
      final dynamic decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Formato inesperado');
      }
      final bool hydrated = _hydrateState(decoded, fromFallback: false);
      if (!hydrated) {
        throw const FormatException('No fue posible interpretar la informacion');
      }
    } catch (e) {
      debugPrint('Error cargando mantenimientos: $e');
      final bool fallbackLoaded = _loadFallbackData();
      if (!fallbackLoaded && mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  bool _hydrateState(Map<String, dynamic> decoded, {required bool fromFallback}) {
    try {
      final List<_TipoMantenimiento> tipos = (decoded['tipos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_TipoMantenimiento.fromMap)
          .toList();
      final Map<int, _TipoMantenimiento> tiposPorId = {
        for (final _TipoMantenimiento tipo in tipos) tipo.id: tipo,
      };

      final List<_Mantenimiento> mantenimientos = (decoded['mantenimientos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_Mantenimiento.fromMap)
          .toList();

      final List<_HistorialMantenimiento> historial = (decoded['historial'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_HistorialMantenimiento.fromMap)
          .toList();

      final Map<int, List<_HistorialMantenimiento>> grouped = <int, List<_HistorialMantenimiento>>{};
      for (final _HistorialMantenimiento registro in historial) {
        grouped.putIfAbsent(registro.mantenimientoId, () => <_HistorialMantenimiento>[]).add(registro);
      }

      int siguienteHistorial = 1;
      for (final _HistorialMantenimiento item in historial) {
        if (item.id >= siguienteHistorial) {
          siguienteHistorial = item.id + 1;
        }
      }

      final List<_MantenimientoDetalle> todos = mantenimientos.map((mantenimiento) {
        final _TipoMantenimiento? tipo = tiposPorId[mantenimiento.tipoId];
        final List<_HistorialMantenimiento> hist = grouped[mantenimiento.id] ?? const [];
        return _MantenimientoDetalle(mantenimiento: mantenimiento, tipo: tipo, historial: hist);
      }).toList();

      final List<_MantenimientoDetalle> filtrados = _filtrarPorRol(todos);

      if (!mounted) {
        return true;
      }

      setState(() {
        _todosLosDetalles = todos;
        _detalles = filtrados;
          _programados = filtrados
            .where((detalle) => _normalizeStatus(detalle.estadoActual) == 'PROGRAMADO')
            .toList();
        _conteoEstados = _recalcularConteo(filtrados);
        _historialPorMantenimiento = grouped;
        _nextHistorialId = siguienteHistorial;
        _isLoading = false;
        _hasError = false;
        _isFallbackData = fromFallback;
      });
      return true;
    } catch (e) {
      debugPrint('Error procesando dataset de mantenimientos: $e');
      return false;
    }
  }

  bool _loadFallbackData() {
    try {
      const String rawFallback = '{"tipos":[{"id_tipo_mantenimiento":1,"nombre":"Cambio de aceite","descripcion":"Sustitucion de aceite y filtros."},{"id_tipo_mantenimiento":2,"nombre":"Alineacion y balanceo","descripcion":"Ajuste de direccion y balance de ruedas."},{"id_tipo_mantenimiento":3,"nombre":"Revision de frenos","descripcion":"Inspeccion de discos, pastillas y liquidos."}],"mantenimientos":[{"id_mantenimiento":9001,"id_vehiculo":302,"id_usuario":"1","id_tipo_mantenimiento":1,"fecha_sugerida":"2025-01-12T08:00:00Z","fecha_programada":"2025-01-15T09:30:00Z","fecha_realizado":null,"kilometraje":65210,"costo":160000,"taller":"Taller Express","estado":"PROGRAMADO","observaciones":"Recordar confirmar disponibilidad del vehiculo."},{"id_mantenimiento":9002,"id_vehiculo":302,"id_usuario":"1","id_tipo_mantenimiento":3,"fecha_sugerida":"2024-11-20T10:00:00Z","fecha_programada":"2024-11-22T14:00:00Z","fecha_realizado":"2024-11-22T16:00:00Z","kilometraje":63000,"costo":210000,"taller":"ServiFrenos Norte","estado":"COMPLETADO","observaciones":"Cambio de pastillas delanteras."}],"historial":[{"id_historial":9801,"id_mantenimiento":9001,"accion":"PROGRAMADO","fecha":"2025-01-05T11:05:00Z","comentario":"Empresa confirma cita en Taller Express."},{"id_historial":9802,"id_mantenimiento":9001,"accion":"SUGERIDO","fecha":"2025-01-03T10:00:00Z","comentario":"Sistema sugirio mantenimiento por kilometraje."},{"id_historial":9803,"id_mantenimiento":9002,"accion":"COMPLETADO","fecha":"2024-11-22T16:10:00Z","comentario":"Conductor recibe vehiculo y verifica frenos."}]}';
      final Map<String, dynamic> decoded = json.decode(rawFallback) as Map<String, dynamic>;
      return _hydrateState(decoded, fromFallback: true);
    } catch (e) {
      debugPrint('Error cargando datos de muestra: $e');
      return false;
    }
  }

  List<_MantenimientoDetalle> _filtrarPorRol(List<_MantenimientoDetalle> todos) {
    if (!_isConductor) {
      return todos;
    }
    final String? userId = widget.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      final List<_MantenimientoDetalle> propios = todos
          .where((detalle) => detalle.mantenimiento.usuarioId == userId)
          .toList();
      if (propios.isNotEmpty) {
        return propios;
      }
    }
    final List<_MantenimientoDetalle> fallback = todos
        .where((detalle) => detalle.mantenimiento.usuarioId == '1')
        .toList();
    return fallback.isNotEmpty ? fallback : todos;
  }

  Map<String, int> _recalcularConteo(List<_MantenimientoDetalle> detalles) {
    final Map<String, int> conteo = <String, int>{};
    for (final _MantenimientoDetalle detalle in detalles) {
      final String key = detalle.estadoActual;
      conteo.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return conteo;
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

    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 720;
        final bool isTableCompact = width < 1000;
        return _buildContent(isCompact, isTableCompact);
      },
    );

    // Si es empresa, agregar FAB para crear mantenimiento
    if (_isEmpresa) {
      return Stack(
        children: [
          content,
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: _showNewMaintenanceModal,
              backgroundColor: const Color(0xFF4F4CE8),
              child: const Icon(Icons.build_rounded, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return content;
  }

  Widget _buildContent(bool isCompact, bool isTableCompact) {
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
                : isTableCompact
                    ? 900
                    : 1120,
          ),
          child: _shouldSplitLayout && !isCompact
              ? _buildSplitLayout(isCompact, isTableCompact)
              : _buildVerticalLayout(isCompact, isTableCompact),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(bool isCompact, bool isTableCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isConductor ? 'Mantenimientos asignados' : 'Gestión de mantenimientos',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isConductor
              ? 'Consulta el plan de mantenimiento que la empresa programó para tus vehículos.'
              : 'Monitorea el estado de los mantenimientos y coordina acciones con los conductores.',
          style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
        ),
        if (_isFallbackData) ...[
          const SizedBox(height: 14),
          _buildFallbackNotice(),
        ],
        const SizedBox(height: 20),
        _buildSummaryChips(isCompact),
        const SizedBox(height: 20),
        _buildProgramadosSection(isTableCompact: isTableCompact, isCompact: isCompact),
        const SizedBox(height: 24),
        _buildHistorialSection(isCompact),
      ],
    );
  }

  Widget _buildSplitLayout(bool isCompact, bool isTableCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isConductor ? 'Mantenimientos asignados' : 'Gestión de mantenimientos',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isConductor
              ? 'Consulta el plan de mantenimiento que la empresa programó para tus vehículos.'
              : 'Monitorea el estado de los mantenimientos y coordina acciones con los conductores.',
          style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
        ),
        if (_isFallbackData) ...[
          const SizedBox(height: 14),
          _buildFallbackNotice(),
        ],
        const SizedBox(height: 20),
        _buildSummaryChips(isCompact),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildProgramadosSection(isTableCompact: isTableCompact, isCompact: isCompact),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildHistorialSection(isCompact),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgramadosSection({required bool isTableCompact, required bool isCompact}) {
    if (_programados.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, color: Colors.white54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No hay mantenimientos programados en este momento.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12.5 : 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mantenimientos programados',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildMantenimientosView(_programados, isTableCompact),
      ],
    );
  }

  Widget _buildHistorialSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial reciente',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildHistorialReciente(isCompact),
      ],
    );
  }

  Widget _buildMantenimientosView(List<_MantenimientoDetalle> detalles, bool isTableCompact) {
    if (isTableCompact || _isConductor) {
      return Column(
        children: detalles
            .map((detalle) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildMantenimientoCard(detalle),
                ))
            .toList(),
      );
    }
    return _buildDataTable(detalles);
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

  Widget _buildFallbackNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mostramos datos de referencia porque no fue posible cargar los mantenimientos reales.',
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<_MantenimientoDetalle> detalles) {
    final List<_MantenimientoDetalle> ordered = List<_MantenimientoDetalle>.from(detalles)
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
          dataRowMinHeight: 70,
          dataRowMaxHeight: 130,
          columns: const [
            DataColumn(label: Text('Mantenimiento')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Fechas')),
            DataColumn(label: Text('Taller')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: ordered.map(_buildDataRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(_MantenimientoDetalle detalle) {
    return DataRow(
      cells: [
        DataCell(_buildMantenimientoCell(detalle.mantenimiento)),
        DataCell(Text(detalle.tipo?.nombre ?? 'Sin tipo', style: const TextStyle(color: Colors.white))),
        DataCell(_buildEstadoTag(detalle.estadoActual)),
        DataCell(_buildFechasCell(detalle.mantenimiento)),
        DataCell(Text(detalle.mantenimiento.taller, style: const TextStyle(color: Colors.white70))),
        DataCell(
          TextButton(
            onPressed: () => _openComentarioSheet(detalle),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Enviar comentario'),
          ),
        ),
      ],
    );
  }

  Widget _buildMantenimientoCell(_Mantenimiento mantenimiento) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#${mantenimiento.id} - Veh ${mantenimiento.vehiculoId}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${mantenimiento.kilometraje} km',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (mantenimiento.observaciones.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            mantenimiento.observaciones,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildFechasCell(_Mantenimiento mantenimiento) {
    final List<String> lines = <String>[];
    lines.add('Sugerida: ${_formatDate(mantenimiento.fechaSugerida)}');
    lines.add('Programada: ${_formatDate(mantenimiento.fechaProgramada)}');
    lines.add('Realizada: ${_formatDate(mantenimiento.fechaRealizada)}');
    return Text(lines.join('\n'), style: const TextStyle(color: Colors.white70));
  }

  Widget _buildMantenimientoCard(_MantenimientoDetalle detalle) {
    final _Mantenimiento mantenimiento = detalle.mantenimiento;
    final _TipoMantenimiento? tipo = detalle.tipo;
    final _HistorialMantenimiento? ultimo = detalle.ultimoMovimiento;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
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
                      '#${mantenimiento.id} - Veh ${mantenimiento.vehiculoId}',
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildInfoBadge(Icons.calendar_month, 'Sugerida ${_formatShort(mantenimiento.fechaSugerida)}'),
              _buildInfoBadge(Icons.event_available, 'Programada ${_formatShort(mantenimiento.fechaProgramada)}'),
              _buildInfoBadge(Icons.done_all, 'Realizada ${_formatShort(mantenimiento.fechaRealizada)}'),
              _buildInfoBadge(Icons.speed, '${mantenimiento.kilometraje} km'),
              if (mantenimiento.costo > 0)
                _buildInfoBadge(Icons.attach_money, ' 24${mantenimiento.costo}'),
              _buildInfoBadge(Icons.store_mall_directory, mantenimiento.taller),
            ],
          ),
          if (mantenimiento.observaciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              mantenimiento.observaciones,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (ultimo != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.update, color: Colors.white60, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_statusLabel(ultimo.accion)} • ${_formatShort(ultimo.fecha)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openComentarioSheet(detalle),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Enviar comentario'),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEstadoTag(String estado) {
    final Color color = _statusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            _statusLabel(estado),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialReciente(bool isCompact) {
    final List<_HistorialMantenimiento> registros = _detalles
        .expand((detalle) => detalle.historial)
        .where((hist) => hist.fecha != null && _normalizeStatus(hist.accion) == 'COMPLETADO')
        .toList()
      ..sort((a, b) {
        final DateTime aDate = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (registros.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Text(
          'Aun no hay mantenimientos completados.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final int maxItems = _shouldSplitLayout ? 4 : 6;
    final List<_HistorialMantenimiento> recientes = registros.take(maxItems).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < recientes.length; i++) ...[
            _buildHistorialItem(recientes[i]),
            if (i != recientes.length - 1) const Divider(color: Colors.white24),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorialItem(_HistorialMantenimiento registro) {
    final _MantenimientoDetalle detalle = _detalles.firstWhere(
      (element) => element.mantenimiento.id == registro.mantenimientoId,
      orElse: () => _todosLosDetalles.firstWhere(
        (element) => element.mantenimiento.id == registro.mantenimientoId,
        orElse: () => _detalles.first,
      ),
    );

    final Color color = _statusColor(registro.accion);

    return InkWell(
      onTap: () => _showDetalleHistorial(registro, detalle),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
              child: Icon(Icons.auto_fix_high, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${registro.mantenimientoId} • ${_statusLabel(registro.accion)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    registro.comentario.isNotEmpty ? registro.comentario : 'Sin comentarios',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDate(registro.fecha),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openComentarioSheet(_MantenimientoDetalle detalle) async {
    final TextEditingController controller = TextEditingController();
    String tipoSeleccionado = 'Comentario';
    String? errorText;

    final _HistorialMantenimiento? nuevoHistorial = await showModalBottomSheet<_HistorialMantenimiento>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 18),
                    Text(
                      'Enviar comentario',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comparte una novedad sobre el mantenimiento #${detalle.mantenimiento.id}.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: tipoSeleccionado,
                      items: const [
                        DropdownMenuItem(value: 'Comentario', child: Text('Comentario general')),
                        DropdownMenuItem(value: 'Solicitud de ajuste', child: Text('Solicitud de ajuste')), 
                        DropdownMenuItem(value: 'Confirmación', child: Text('Confirmación de atención')), 
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          tipoSeleccionado = value;
                        });
                      },
                      dropdownColor: _surfaceColor,
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tipo de mensaje',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Mensaje para la empresa',
                        labelStyle: const TextStyle(color: Colors.white70),
                        errorText: errorText,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final String mensaje = controller.text.trim();
                              setModalState(() {
                                errorText = mensaje.isEmpty ? 'Escribe un mensaje para enviarlo' : null;
                              });
                              if (mensaje.isEmpty) {
                                return;
                              }
                              Navigator.of(ctx).pop(
                                _HistorialMantenimiento(
                                  id: _nextHistorialId,
                                  mantenimientoId: detalle.mantenimiento.id,
                                  accion: tipoSeleccionado.toUpperCase(),
                                  fecha: DateTime.now().toUtc(),
                                  comentario: mensaje,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Enviar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    controller.dispose();

    if (nuevoHistorial == null) {
      return;
    }

    setState(() {
      final List<_HistorialMantenimiento> historial = List<_HistorialMantenimiento>.from(
        _historialPorMantenimiento[detalle.mantenimiento.id] ?? const [],
      )
        ..add(nuevoHistorial);
      _historialPorMantenimiento = {
        ..._historialPorMantenimiento,
        detalle.mantenimiento.id: historial,
      };
      _nextHistorialId += 1;
      _detalles = _detalles.map((_MantenimientoDetalle item) {
        if (item.mantenimiento.id == detalle.mantenimiento.id) {
          return _MantenimientoDetalle(
            mantenimiento: item.mantenimiento,
            tipo: item.tipo,
            historial: historial,
          );
        }
        return item;
      }).toList();
      _conteoEstados = _recalcularConteo(_detalles);
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comentario enviado a la empresa.')),
    );
  }

  Future<void> _showDetalleHistorial(
    _HistorialMantenimiento registro,
    _MantenimientoDetalle? detalle,
  ) async {
    final _Mantenimiento? mantenimiento = detalle?.mantenimiento;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Detalle del mantenimiento #${registro.mantenimientoId}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (mantenimiento != null) ...[
                Text('Estado actual: ${_statusLabel(mantenimiento.estado)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('Taller: ${mantenimiento.taller}', style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 16),
              Text('Movimiento', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                '${_statusLabel(registro.accion)} • ${_formatDate(registro.fecha)}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (registro.comentario.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(registro.comentario, style: const TextStyle(color: Colors.white60)),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNewMaintenanceModal() async {
    final TextEditingController tallerController = TextEditingController();
    final TextEditingController observacionesController = TextEditingController();
    final TextEditingController costoController = TextEditingController();
    
    String? selectedVehiculo;
    String? selectedTipo;
    String? errorText;

    final List<String> vehiculos = ['Veh 501', 'Veh 502', 'Veh 503'];
    final List<String> tipos = ['Cambio de aceite', 'Alineacion y balanceo', 'Revision de frenos'];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 18),
                    const Text(
                      'Crear mantenimiento',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Programa un nuevo mantenimiento para los vehículos',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    // Vehículo selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedVehiculo,
                      items: vehiculos.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (value) {
                        setModalState(() => selectedVehiculo = value);
                      },
                      dropdownColor: _surfaceColor,
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Vehículo',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Tipo selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedTipo,
                      items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) {
                        setModalState(() => selectedTipo = value);
                      },
                      dropdownColor: _surfaceColor,
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tipo de mantenimiento',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Taller
                    TextField(
                      controller: tallerController,
                      decoration: InputDecoration(
                        labelText: 'Taller',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    // Costo
                    TextField(
                      controller: costoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Costo estimado',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    // Observaciones
                    TextField(
                      controller: observacionesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        labelStyle: const TextStyle(color: Colors.white70),
                        errorText: errorText,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                errorText = null;
                                if (selectedVehiculo == null || selectedVehiculo!.isEmpty) {
                                  errorText = 'Selecciona un vehículo';
                                } else if (selectedTipo == null || selectedTipo!.isEmpty) {
                                  errorText = 'Selecciona tipo de mantenimiento';
                                } else if (tallerController.text.isEmpty) {
                                  errorText = 'Especifica el taller';
                                }
                              });

                              if (errorText != null) return;

                              debugPrint('Nuevo mantenimiento: Veh=$selectedVehiculo, Tipo=$selectedTipo, Taller=${tallerController.text}');

                              Navigator.of(ctx).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Mantenimiento creado correctamente')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Crear mantenimiento'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    tallerController.dispose();
    observacionesController.dispose();
    costoController.dispose();
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
        children: const [
          Icon(Icons.build_circle_outlined, color: Colors.white54, size: 48),
          SizedBox(height: 14),
          Text('No hay mantenimientos programados.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Cuando la empresa te asigne un mantenimiento aparecerá aquí.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  int _statusPriority(String value) {
    const Map<String, int> order = {
      'SUGERIDO': 0,
      'PROGRAMADO': 1,
      'EN_PROCESO': 2,
      'COMPLETADO': 3,
      'CANCELADO': 4,
    };
    return order[_normalizeStatus(value)] ?? 9;
  }

  String _normalizeStatus(String value) => value.toUpperCase();

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return _dateFormat.format(value.toLocal());
  }

  String _formatShort(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return DateFormat('dd/MM').format(value.toLocal());
  }

  String _statusLabel(String value) {
    final String normalized = _normalizeStatus(value);
    switch (normalized) {
      case 'SUGERIDO':
        return 'Sugerido';
      case 'PROGRAMADO':
        return 'Programado';
      case 'EN_PROCESO':
        return 'En proceso';
      case 'COMPLETADO':
        return 'Completado';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
    }
  }

  Color _statusColor(String value) {
    final String normalized = _normalizeStatus(value);
    switch (normalized) {
      case 'COMPLETADO':
        return _successColor;
      case 'EN_PROCESO':
      case 'PROGRAMADO':
        return _infoColor;
      case 'SUGERIDO':
        return _warningColor;
      case 'CANCELADO':
        return _dangerColor;
      default:
        return _accentColor;
    }
  }
}
