import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/l10n/app_language.dart';

import '../../services/api_service.dart';
import '../utils/shimmer_skeleton.dart';

class MantenimientosWidget extends StatefulWidget {
  final String role;
  final String? userId;

  final String? personaUserId;
  final String? personaRole;
  final String? personaNombre;

  final String? vehiculoId;
  final String? vehiculoPlaca;
  final String? initialSearch;

  const MantenimientosWidget({
    super.key,
    required this.role,
    this.userId,
    this.personaUserId,
    this.personaRole,
    this.personaNombre,
    this.vehiculoId,
    this.vehiculoPlaca,
    this.initialSearch,
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
      id:
          int.tryParse(
            map['id']?.toString() ??
                map['id_tipo_mantenimiento']?.toString() ??
                map['idTipoMantenimiento']?.toString() ??
                '',
          ) ??
          0,
      nombre:
          map['nombre']?.toString() ??
          map['tipoMantenimiento']?.toString() ??
          'Tipo sin nombre',
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
  final String prioridad;
  final String vehiculoLabel;
  final String propietarioNombre;
  final String conductorNombre;

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
    required this.prioridad,
    required this.vehiculoLabel,
    required this.propietarioNombre,
    required this.conductorNombre,
  });

  factory _Mantenimiento.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      final String raw = value?.toString() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    String buildVehiculoLabel(Map<String, dynamic> map) {
      final vehiculo = map['vehiculo'];

      if (vehiculo is Map) {
        final marca = vehiculo['marca']?.toString() ?? '';
        final modelo = vehiculo['modelo']?.toString() ?? '';
        final placa = vehiculo['placa']?.toString() ?? '';
        final nombre = '$marca $modelo'.trim();

        if (placa.isNotEmpty) {
          return '${nombre.isEmpty ? 'Vehículo' : nombre} - $placa';
        }
      }

      final marca =
          map['marca']?.toString() ?? map['vehiculoMarca']?.toString() ?? '';
      final modelo =
          map['modelo']?.toString() ?? map['vehiculoModelo']?.toString() ?? '';
      final placa =
          map['placa']?.toString() ?? map['vehiculoPlaca']?.toString() ?? '';
      final nombre = '$marca $modelo'.trim();

      if (placa.isNotEmpty) {
        return '${nombre.isEmpty ? 'Vehículo' : nombre} - $placa';
      }

      return '';
    }

    String readNombrePersona(dynamic value) {
      if (value is! Map) return '';

      final usuario = value['usuario'];

      if (usuario is Map) {
        final nombre = usuario['nombre']?.toString() ?? '';
        final apellido = usuario['apellido']?.toString() ?? '';
        return '$nombre $apellido'.trim();
      }

      final nombre = value['nombre']?.toString() ?? '';
      final apellido = value['apellido']?.toString() ?? '';
      return '$nombre $apellido'.trim();
    }

    final propietarioNombre =
        map['propietarioNombre']?.toString() ??
        map['nombrePropietario']?.toString() ??
        readNombrePersona(map['propietario']);

    final conductorNombre =
        map['conductorNombre']?.toString() ??
        map['nombreConductor']?.toString() ??
        readNombrePersona(map['conductor']);

    return _Mantenimiento(
      id:
          int.tryParse(
            map['id']?.toString() ?? map['id_mantenimiento']?.toString() ?? '',
          ) ??
          0,

      vehiculoId:
          int.tryParse(
            map['vehiculoId']?.toString() ??
                map['idVehiculo']?.toString() ??
                map['id_vehiculo']?.toString() ??
                (map['vehiculo'] is Map
                    ? ((map['vehiculo']['idVehiculo'] ??
                              map['vehiculo']['id_vehiculo'] ??
                              map['vehiculo']['id'])
                          ?.toString())
                    : '') ??
                '',
          ) ??
          0,

      usuarioId:
          map['usuarioId']?.toString() ?? map['id_usuario']?.toString() ?? '',

      tipoId:
          int.tryParse(
            map['tipoMantenimientoId']?.toString() ??
                map['idTipoMantenimiento']?.toString() ??
                map['id_tipo_mantenimiento']?.toString() ??
                '',
          ) ??
          0,

      fechaSugerida: parseDate(map['fechaSugerida'] ?? map['fecha_sugerida']),

      fechaProgramada: parseDate(
        map['fechaProgramada'] ?? map['fecha_programada'],
      ),

      fechaRealizada: parseDate(
        map['fechaRealizado'] ??
            map['fechaRealizada'] ??
            map['fecha_realizado'],
      ),

      kilometraje: int.tryParse(map['kilometraje']?.toString() ?? '') ?? 0,
      costo: int.tryParse(map['costo']?.toString() ?? '') ?? 0,
      taller: map['taller']?.toString() ?? '',
      estado: map['estado']?.toString() ?? 'SUGERIDO',
      observaciones: map['observaciones']?.toString() ?? '',
      prioridad: map['prioridad']?.toString() ?? 'Media',
      vehiculoLabel: buildVehiculoLabel(map),
      propietarioNombre: propietarioNombre,
      conductorNombre: conductorNombre,
    );
  }
}

class _MantenimientoDetalle {
  final _Mantenimiento mantenimiento;
  final _TipoMantenimiento? tipo;

  const _MantenimientoDetalle({
    required this.mantenimiento,
    required this.tipo,
  });

  String get estadoActual => mantenimiento.estado.toUpperCase();
}

class _MantenimientosWidgetState extends State<MantenimientosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _surfaceColor = Color(0xFF121738);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);
  static const Color _infoColor = Color(0xFF3DA9F5);

  double _pagePadding(double width) {
    if (width < 380) return 12;
    if (width < 720) return 16;
    return 24;
  }

  bool _isLoading = true;
  bool _hasError = false;
  List<_MantenimientoDetalle> _detalles = const [];
  Map<String, int> _conteoEstados = const {};

  // Datos del backend
  List<Map<String, dynamic>> _vehiculos = const [];
  List<Map<String, dynamic>> _tiposMantenimiento = const [];

  bool get _isConductor => widget.role.toLowerCase() == 'conductor';
  bool get _isPropietario => widget.role.toLowerCase() == 'propietario';
  bool get _isEmpresa => widget.role.toLowerCase() == 'empresa';
  bool get _viendoPersona =>
      widget.personaUserId != null && widget.personaUserId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    maintenanceSearch = widget.initialSearch?.trim().toLowerCase() ?? '';
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MantenimientosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSearch != oldWidget.initialSearch) {
      setState(() {
        maintenanceSearch = widget.initialSearch?.trim().toLowerCase() ?? '';
      });
    }
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = widget.userId ?? prefs.getString('user_id');
      final results = await Future.wait([
        ApiService.getMantenimientos(
          role: widget.role,
          userId: userId,
          token: token,
        ),
        ApiService.getTiposMantenimiento(token: token),

        // Si viene desde una persona, cargamos todos los vehículos de empresa
        // y luego filtramos por el usuario seleccionado.
        ApiService.getVehiculosPorRol(
          role: _viendoPersona ? 'Empresa' : widget.role,
          userId: _viendoPersona ? null : userId,
          token: token,
        ),
      ]);

      final mantenimientosData = results[0];
      final tiposData = results[1];
      final vehiculosData = results[2];
      final tipos = tiposData
          .map((map) => _TipoMantenimiento.fromMap(map))
          .toList();
      final tiposPorId = {for (final tipo in tipos) tipo.id: tipo};
      final mantenimientos = mantenimientosData
          .map((map) => _Mantenimiento.fromMap(map))
          .toList();
      final todos = mantenimientos.map((_Mantenimiento mantenimiento) {
        final _TipoMantenimiento? tipo = tiposPorId[mantenimiento.tipoId];
        return _MantenimientoDetalle(mantenimiento: mantenimiento, tipo: tipo);
      }).toList();

      final vehiculosFiltrados = _viendoPersona
          ? filtrarVehiculosPorUsuarioSeleccionado(vehiculosData)
          : vehiculosData;

      List<_MantenimientoDetalle> filtrados = _viendoPersona
          ? filtrarMantenimientosPorVehiculos(todos, vehiculosFiltrados)
          : filtrarPorRolConVehiculos(todos, vehiculosData);

      final int? vehiculoSeleccionadoId = int.tryParse(
        widget.vehiculoId?.toString() ?? '',
      );

      if (vehiculoSeleccionadoId != null && vehiculoSeleccionadoId > 0) {
        filtrados = filtrados
            .where(
              (detalle) =>
                  detalle.mantenimiento.vehiculoId == vehiculoSeleccionadoId,
            )
            .toList();
      }

      if (mounted) {
        setState(() {
          _vehiculos = vehiculosData;
          _tiposMantenimiento = tiposData;
          _detalles = filtrados;
          _conteoEstados = recalcularConteo(filtrados);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando datos del backend: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Map<String, int> recalcularConteo(List<_MantenimientoDetalle> detalles) {
    final Map<String, int> conteo = <String, int>{};
    for (final _MantenimientoDetalle detalle in detalles) {
      final String key = detalle.estadoActual;
      conteo.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return conteo;
  }

  List<String> availableVehiculos() {
    return _vehiculos.map((vehiculo) {
      final marca = vehiculo['marca']?.toString() ?? '';
      final modelo = vehiculo['modelo']?.toString() ?? '';
      final placa = vehiculo['placa']?.toString() ?? 'Sin placa';
      final nombreVehiculo = '$marca $modelo'.trim();
      return '${nombreVehiculo.isEmpty ? 'Vehículo' : nombreVehiculo} - $placa';
    }).toList();
  }

  List<String> availableTipos() {
    return _tiposMantenimiento
        .map((tipo) {
          return tipo['nombre']?.toString() ??
              tipo['tipoMantenimiento']?.toString() ??
              tipo['nombreTipo']?.toString() ??
              'Sin nombre';
        })
        .where((nombre) => nombre != 'Sin nombre')
        .toList();
  }

  int getVehiculoIdFromSelection(String? selectedVehiculo) {
    if (selectedVehiculo == null) return 0;

    final vehiculo = _vehiculos.firstWhere((v) {
      final marca = v['marca']?.toString() ?? '';
      final modelo = v['modelo']?.toString() ?? '';
      final placa = v['placa']?.toString() ?? 'Sin placa';

      final nombreVehiculo = '$marca $modelo'.trim();
      final display =
          '${nombreVehiculo.isEmpty ? 'Vehículo' : nombreVehiculo} - $placa';

      return display == selectedVehiculo;
    }, orElse: () => <String, dynamic>{});

    return vehiculo['id_vehiculo'] ??
        vehiculo['idVehiculo'] ??
        vehiculo['id'] ??
        0;
  }

  int getTipoIdFromSelection(String? selectedTipo) {
    if (selectedTipo == null) return 0;

    final tipo = _tiposMantenimiento.firstWhere((t) {
      final nombre =
          t['nombre']?.toString() ??
          t['tipoMantenimiento']?.toString() ??
          t['nombreTipo']?.toString() ??
          '';

      return nombre == selectedTipo;
    }, orElse: () => <String, dynamic>{});

    return tipo['id'] ??
        tipo['id_tipo_mantenimiento'] ??
        tipo['idTipoMantenimiento'] ??
        tipo['tipoMantenimientoId'] ??
        0;
  }

  bool usuarioTieneAccesoAlVehiculo(int vehiculoId) {
    if (!(_isConductor || _isPropietario)) {
      return true;
    }

    if (_vehiculos.isEmpty) {
      return false;
    }

    return _vehiculos.any((vehiculo) {
      final int id =
          int.tryParse(
            (vehiculo['id'] ??
                    vehiculo['id_vehiculo'] ??
                    vehiculo['idVehiculo'] ??
                    0)
                .toString(),
          ) ??
          0;

      return id == vehiculoId;
    });
  }

  String maintenanceSearch = '';
  String _vistaEmpresa = 'mantenimiento';

  List<_MantenimientoDetalle> filtrarPorRolConVehiculos(
    List<_MantenimientoDetalle> todos,
    List<Map<String, dynamic>> vehiculosData,
  ) {
    if (!(_isConductor || _isPropietario)) {
      return todos;
    }

    if (vehiculosData.isEmpty) {
      //debugPrint('⚠️ No hay vehículos asignados al usuario.');
      return [];
    }

    final Set<int> vehiculoIds = vehiculosData.map((vehiculo) {
      return int.tryParse(
            (vehiculo['id'] ??
                    vehiculo['id_vehiculo'] ??
                    vehiculo['idVehiculo'] ??
                    0)
                .toString(),
          ) ??
          0;
    }).toSet();

    //debugPrint('🚗 Vehículos asignados: $vehiculoIds');

    return todos.where((detalle) {
      return vehiculoIds.contains(detalle.mantenimiento.vehiculoId);
    }).toList();
  }

  List<Map<String, dynamic>> filtrarVehiculosPorUsuarioSeleccionado(
    List<Map<String, dynamic>> vehiculosData,
  ) {
    final selectedUserId = widget.personaUserId?.trim() ?? '';
    final selectedRole = widget.personaRole?.toUpperCase().trim() ?? '';

    if (selectedUserId.isEmpty) return [];

    return vehiculosData.where((vehiculo) {
      final conductor = vehiculo['conductor'];
      final propietario = vehiculo['propietario'];

      if (selectedRole == 'CONDUCTOR' && conductor is Map) {
        final usuario = conductor['usuario'];
        if (usuario is Map) {
          final id =
              usuario['id']?.toString() ??
              usuario['idUsuario']?.toString() ??
              usuario['id_usuario']?.toString() ??
              '';
          return id == selectedUserId;
        }
      }

      if (selectedRole == 'PROPIETARIO' && propietario is Map) {
        final usuario = propietario['usuario'];
        if (usuario is Map) {
          final id =
              usuario['id']?.toString() ??
              usuario['idUsuario']?.toString() ??
              usuario['id_usuario']?.toString() ??
              '';
          return id == selectedUserId;
        }
      }

      return false;
    }).toList();
  }

  List<_MantenimientoDetalle> filtrarMantenimientosPorVehiculos(
    List<_MantenimientoDetalle> todos,
    List<Map<String, dynamic>> vehiculosData,
  ) {
    if (vehiculosData.isEmpty) return [];

    final Set<int> vehiculoIds = vehiculosData.map((vehiculo) {
      return int.tryParse(
            (vehiculo['id'] ??
                    vehiculo['id_vehiculo'] ??
                    vehiculo['idVehiculo'] ??
                    0)
                .toString(),
          ) ??
          0;
    }).toSet();

    return todos.where((detalle) {
      return vehiculoIds.contains(detalle.mantenimiento.vehiculoId);
    }).toList();
  }

  String getVehiculoDisplayName(int vehiculoId, {String fallback = ''}) {
    final vehiculo = _vehiculos.firstWhere(
      (v) => (v['id_vehiculo'] ?? v['idVehiculo'] ?? v['id']) == vehiculoId,
      orElse: () => <String, dynamic>{},
    );

    if (vehiculo.isNotEmpty) {
      final marca = vehiculo['marca']?.toString() ?? '';
      final modelo = vehiculo['modelo']?.toString() ?? '';
      final placa = vehiculo['placa']?.toString() ?? 'Sin placa';
      final nombreVehiculo = '$marca $modelo'.trim();

      return '${nombreVehiculo.isEmpty ? 'Vehículo' : nombreVehiculo} - $placa';
    }

    if (fallback.trim().isNotEmpty) {
      return fallback;
    }

    return 'Vehículo $vehiculoId';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return buildShimmerLoading();
    }

    if (_hasError) {
      return buildErrorState();
    }

    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 720;
        final bool isTableCompact = width < 1000;
        return buildContent(isCompact, isTableCompact);
      },
    );

    if (_isEmpresa) {
      return Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: showNewMaintenanceModal,
              backgroundColor: const Color(0xFF4F4CE8),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    return content;
  }

  Widget buildShimmerLoading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 720;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 24,
            24,
            isCompact ? 16 : 24,
            isCompact ? 120 : 64,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isCompact ? 760 : 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(
                    width: isCompact ? 200 : 300,
                    height: isCompact ? 18 : 22,
                  ),
                  const SizedBox(height: 6),
                  ShimmerSkeleton(
                    width: isCompact ? 250 : 400,
                    height: isCompact ? 12 : 13,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: List.generate(3, (index) => ShimmerSummaryChip()),
                  ),
                  const SizedBox(height: 20),
                  ShimmerSkeleton(
                    width: double.infinity,
                    height: 50,
                    borderRadius: 14,
                  ),
                  const SizedBox(height: 20),
                  ShimmerSkeleton(
                    width: isCompact ? 180 : 200,
                    height: isCompact ? 16 : 18,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(
                      2,
                      (index) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  ShimmerSkeleton(width: 80, height: 16),
                                  const Spacer(),
                                  ShimmerSkeleton(width: 20, height: 12),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                              child: Column(
                                children: List.generate(
                                  3,
                                  (cardIndex) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        18,
                                        18,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    ShimmerSkeleton(
                                                      width: 150,
                                                      height: 14,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ShimmerSkeleton(
                                                      width: 100,
                                                      height: 13,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ShimmerSkeleton(
                                                width: 60,
                                                height: 24,
                                                borderRadius: 12,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 8,
                                            children: List.generate(
                                              4,
                                              (badgeIndex) => ShimmerSkeleton(
                                                width: 80,
                                                height: 24,
                                                borderRadius: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShimmerSkeleton(
                    width: isCompact ? 180 : 200,
                    height: isCompact ? 16 : 18,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShimmerSkeleton(width: 150, height: 14),
                                        const SizedBox(height: 6),
                                        ShimmerSkeleton(width: 100, height: 13),
                                      ],
                                    ),
                                  ),
                                  ShimmerSkeleton(
                                    width: 60,
                                    height: 24,
                                    borderRadius: 12,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: List.generate(
                                  3,
                                  (badgeIndex) => ShimmerSkeleton(
                                    width: 70,
                                    height: 24,
                                    borderRadius: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildContent(bool isCompact, bool isTableCompact) {
    final width = MediaQuery.of(context).size.width;
    final padding = _pagePadding(width);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(padding, 20, padding, isCompact ? 120 : 72),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact
                ? 760
                : isTableCompact
                ? 900
                : 1120,
          ),
          child: buildVerticalLayout(isCompact, isTableCompact),
        ),
      ),
    );
  }

  Widget buildMaintenanceSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          maintenanceSearch = value.trim().toLowerCase();
        });
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintText: context.t('maintenance.searchHint'),
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
    );
  }

  Widget buildVistaEmpresaToggle({bool isCompact = false}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: isCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildVistaButton(
                  label: 'Por mantenimiento',
                  icon: Icons.build_circle,
                  value: 'mantenimiento',
                  isCompact: true,
                ),
                buildVistaButton(
                  label: 'Por vehículo',
                  icon: Icons.directions_car,
                  value: 'vehiculo',
                  isCompact: true,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildVistaButton(
                  label: 'Por mantenimiento',
                  icon: Icons.build_circle,
                  value: 'mantenimiento',
                ),
                buildVistaButton(
                  label: 'Por vehículo',
                  icon: Icons.directions_car,
                  value: 'vehiculo',
                ),
              ],
            ),
    );
  }

  Widget buildVistaButton({
    required String label,
    required IconData icon,
    required String value,
    bool isCompact = false,
  }) {
    final bool selected = _vistaEmpresa == value;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _vistaEmpresa = value;
        });
      },
      child: Container(
        width: isCompact ? 190 : null,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? _accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: isCompact ? 16 : 18),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVerticalLayout(bool isCompact, bool isTableCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bool smallHeader = constraints.maxWidth < 760;

            final title = Text(
              _viendoPersona
                  ? '${context.t('maintenance.personTitle')} ${widget.personaNombre ?? 'la persona'}'
                  : widget.vehiculoId != null
                  ? '${context.t('maintenance.vehicleTitle')} ${widget.vehiculoPlaca ?? 'vehículo'}'
                  : _isConductor
                  ? context.t('maintenance.assignedTitle')
                  : _isPropietario
                  ? context.t('maintenance.myVehiclesTitle')
                  : context.t('maintenance.managementTitle'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 18 : 22,
                fontWeight: FontWeight.w700,
              ),
            );

            final toggle =
                (_isEmpresa && !_viendoPersona && widget.vehiculoId == null)
                ? buildVistaEmpresaToggle(isCompact: smallHeader)
                : const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (_isEmpresa &&
                    !_viendoPersona &&
                    widget.vehiculoId == null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: toggle),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          _isConductor
              ? 'Consulta el plan de mantenimiento que la empresa programó para tus vehículos.'
              : _isPropietario
              ? 'Consulta los mantenimientos programados para tus vehículos.'
              : widget.vehiculoId != null
              ? 'Consulta solo los mantenimientos asociados a este vehículo.'
              : 'Monitorea el estado de los mantenimientos y coordina acciones con los conductores.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isCompact ? 12 : 13,
          ),
        ),
        const SizedBox(height: 20),
        buildSummaryChips(isCompact),
        const SizedBox(height: 20),
        buildMaintenanceSearch(),
        const SizedBox(height: 20),
        if (_isEmpresa && _vistaEmpresa == 'vehiculo') ...[
          buildActivosDashboard(isCompact),
          const SizedBox(height: 24),
          buildMantenimientosPorVehiculo(isCompact),
        ] else ...[
          buildActivosDashboard(isCompact),
          const SizedBox(height: 24),
          buildHistorialPorTipo(isCompact),
        ],
      ],
    );
  }

  List<_MantenimientoDetalle> filtrarBusqueda(
    List<_MantenimientoDetalle> lista,
  ) {
    if (maintenanceSearch.isEmpty) return lista;

    return lista.where((detalle) {
      final vehiculo = getVehiculoDisplayName(
        detalle.mantenimiento.vehiculoId,
        fallback: detalle.mantenimiento.vehiculoLabel,
      ).toLowerCase();
      final tipo = detalle.tipo?.nombre.toLowerCase() ?? '';
      final conductor = detalle.mantenimiento.conductorNombre.toLowerCase();
      final propietario = detalle.mantenimiento.propietarioNombre.toLowerCase();

      return vehiculo.contains(maintenanceSearch) ||
          tipo.contains(maintenanceSearch) ||
          conductor.contains(maintenanceSearch) ||
          propietario.contains(maintenanceSearch);
    }).toList();
  }

  Map<String, List<_MantenimientoDetalle>> agruparPorTipo(
    List<_MantenimientoDetalle> lista,
  ) {
    final Map<String, List<_MantenimientoDetalle>> grupos = {};

    for (final item in lista) {
      final tipo = item.tipo?.nombre ?? 'Sin tipo';

      grupos.putIfAbsent(tipo, () => []);
      grupos[tipo]!.add(item);
    }

    return grupos;
  }

  String getIconoTipo(String tipo) {
    final t = tipo.toLowerCase();

    if (t.contains('preventivo')) return '🔧';
    if (t.contains('correctivo')) return '🚨';
    if (t.contains('aceite')) return '🛢';
    if (t.contains('revision') || t.contains('revisión')) return '⚙';

    return '🔧';
  }

  Widget buildActivosDashboard(bool isCompact) {
    final sugeridos =
        filtrarBusqueda(
          _detalles.where((d) {
            return d.mantenimiento.estado.toUpperCase().trim() == 'SUGERIDO';
          }).toList(),
        )..sort((a, b) {
          final prioridadA = priorityRank(a.mantenimiento.prioridad);
          final prioridadB = priorityRank(b.mantenimiento.prioridad);

          if (prioridadA != prioridadB) {
            return prioridadA.compareTo(prioridadB);
          }

          final fechaA = a.mantenimiento.fechaSugerida ?? DateTime(2100);
          final fechaB = b.mantenimiento.fechaSugerida ?? DateTime(2100);
          return fechaA.compareTo(fechaB);
        });

    final programados =
        filtrarBusqueda(
          _detalles.where((d) {
            return d.mantenimiento.estado.toUpperCase().trim() == 'PROGRAMADO';
          }).toList(),
        )..sort((a, b) {
          final prioridadA = priorityRank(a.mantenimiento.prioridad);
          final prioridadB = priorityRank(b.mantenimiento.prioridad);

          if (prioridadA != prioridadB) {
            return prioridadA.compareTo(prioridadB);
          }

          final fechaA = a.mantenimiento.fechaProgramada ?? DateTime(2100);
          final fechaB = b.mantenimiento.fechaProgramada ?? DateTime(2100);
          return fechaA.compareTo(fechaB);
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('maintenance.activeTitle'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final small = constraints.maxWidth < 330;

            if (small) {
              return Column(
                children: [
                  buildEstadoDashboardCard(
                    titulo: 'Sugeridos',
                    icono: Icons.lightbulb,
                    cantidad: sugeridos.length,
                    color: _warningColor,
                    onTap: () => abrirListaModal('Sugeridos', sugeridos),
                  ),
                  const SizedBox(height: 12),
                  buildEstadoDashboardCard(
                    titulo: 'Programados',
                    icono: Icons.event_available,
                    cantidad: programados.length,
                    color: _accentColor,
                    onTap: () => abrirListaModal('Programados', programados),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: buildEstadoDashboardCard(
                    titulo: 'Sugeridos',
                    icono: Icons.lightbulb,
                    cantidad: sugeridos.length,
                    color: _warningColor,
                    onTap: () => abrirListaModal('Sugeridos', sugeridos),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildEstadoDashboardCard(
                    titulo: 'Programados',
                    icono: Icons.event_available,
                    cantidad: programados.length,
                    color: _accentColor,
                    onTap: () => abrirListaModal('Programados', programados),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget buildEstadoDashboardCard({
    required String titulo,
    required IconData icono,
    required int cantidad,
    required Color color,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 360;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: small ? 96 : 108,
            padding: EdgeInsets.all(small ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color, size: small ? 24 : 30),
                const Spacer(),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: small ? 13 : 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$cantidad mantenimiento(s)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: small ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildHistorialPorTipo(bool isCompact) {
    final realizados =
        filtrarBusqueda(
          _detalles.where((d) {
            return d.mantenimiento.estado.toUpperCase().trim() == 'REALIZADO';
          }).toList(),
        )..sort((a, b) {
          final fechaA = a.mantenimiento.fechaRealizada ?? DateTime(1900);
          final fechaB = b.mantenimiento.fechaRealizada ?? DateTime(1900);
          return fechaB.compareTo(fechaA);
        });

    if (realizados.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Text(
          'Aún no hay mantenimientos realizados.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final agrupados = agruparPorTipo(realizados);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial por tipo',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width < 360
                ? 1
                : width < 620
                ? 2
                : width < 950
                ? 3
                : 4;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: width < 360 ? 2.4 : 1.55,
              children: agrupados.entries.map((entry) {
                return buildHistorialTipoCard(
                  tipo: entry.key,
                  cantidad: entry.value.length,
                  onTap: () => abrirListaModal(entry.key, entry.value),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget buildMantenimientosPorVehiculo(bool isCompact) {
    final lista = filtrarBusqueda(_detalles);

    final Map<int, List<_MantenimientoDetalle>> grupos = {};

    for (final detalle in lista) {
      final vehiculoId = detalle.mantenimiento.vehiculoId;

      if (vehiculoId <= 0) continue;

      grupos.putIfAbsent(vehiculoId, () => []);
      grupos[vehiculoId]!.add(detalle);
    }

    if (grupos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          context.t('maintenance.noVehicleMaintenance'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('maintenance.byVehicleTitle'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...grupos.entries.map((entry) {
          final vehiculoId = entry.key;
          final mantenimientos = entry.value;

          final sugeridos = mantenimientos
              .where((d) => d.estadoActual == 'SUGERIDO')
              .length;

          final programados = mantenimientos
              .where((d) => d.estadoActual == 'PROGRAMADO')
              .length;

          final realizados = mantenimientos
              .where((d) => d.estadoActual == 'REALIZADO')
              .length;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                collapsedIconColor: Colors.white70,
                iconColor: Colors.white,
                title: Text(
                  getVehiculoDisplayName(
                    vehiculoId,
                    fallback: mantenimientos.first.mantenimiento.vehiculoLabel,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildMiniCountBadge(
                        'Sugeridos',
                        sugeridos,
                        _warningColor,
                      ),
                      buildMiniCountBadge(
                        'Programados',
                        programados,
                        _accentColor,
                      ),
                      buildMiniCountBadge('Realizados', realizados, _infoColor),
                    ],
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: mantenimientos.map((detalle) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: buildMantenimientoCard(detalle),
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget buildMiniCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildHistorialTipoCard({
    required String tipo,
    required int cantidad,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(getIconoTipo(tipo), style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(
              tipo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$cantidad realizado(s)',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFloatingModalShell({
    required Widget child,
    double maxWidth = 560,
    double maxHeightFactor = 0.88,
  }) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width > maxWidth
            ? maxWidth
            : MediaQuery.of(context).size.width * 0.92,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF20276D), Color(0xFF121842), Color(0xFF0D1234)],
          ),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
      ),
    );
  }

  Widget buildFloatingModalHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4F4CE8)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          trailing ??
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
        ],
      ),
    );
  }

  void abrirListaModal(String titulo, List<_MantenimientoDetalle> lista) {
    final ordenados = List<_MantenimientoDetalle>.from(lista)
      ..sort((a, b) {
        final fechaA =
            a.mantenimiento.fechaRealizada ??
            a.mantenimiento.fechaProgramada ??
            a.mantenimiento.fechaSugerida ??
            DateTime(1900);

        final fechaB =
            b.mantenimiento.fechaRealizada ??
            b.mantenimiento.fechaProgramada ??
            b.mantenimiento.fechaSugerida ??
            DateTime(1900);

        return fechaB.compareTo(fechaA);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: buildFloatingModalShell(
            maxWidth: 620,
            maxHeightFactor: 0.90,
            child: Column(
              children: [
                buildFloatingModalHeader(
                  title: titulo,
                  subtitle: '${ordenados.length} mantenimiento(s)',
                  icon: Icons.list_alt_rounded,
                ),
                Expanded(
                  child: ordenados.isEmpty
                      ? Center(
                          child: Text(
                            context.t('maintenance.noVisibleMaintenance'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: ordenados.map((detalle) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildMantenimientoCard(
                                detalle,
                                closeParentAfterAction: true,
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildSummaryChips(bool isCompact) {
    final List<Map<String, dynamic>> chipsData = [
      {
        'label': 'Sugeridos',
        'count': _conteoEstados['SUGERIDO'] ?? 0,
        'color': _warningColor,
      },
      {
        'label': 'Programados',
        'count': _conteoEstados['PROGRAMADO'] ?? 0,
        'color': _warningColor,
      },
      {
        'label': 'Realizados',
        'count': _conteoEstados['REALIZADO'] ?? 0,
        'color': _infoColor,
      },
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 12,
      children: chipsData.map((item) {
        final Color color = item['color'] as Color;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 16,
            vertical: 10,
          ),
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
                item['label'].toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item['count'].toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildMantenimientoCard(
    _MantenimientoDetalle detalle, {
    bool closeParentAfterAction = false,
  }) {
    final _Mantenimiento mantenimiento = detalle.mantenimiento;
    final _TipoMantenimiento? tipo = detalle.tipo;
    final bool finalizado = mantenimiento.estado.toUpperCase() == 'REALIZADO';
    final Color cardColor = finalizado
        ? _infoColor
        : priorityColor(mantenimiento.prioridad);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showMantenimientoDetalleModal(detalle),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardColor.withValues(alpha: 0.45)),
        ),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.of(context).size.width < 380 ? 12 : 18,
          16,
          MediaQuery.of(context).size.width < 380 ? 12 : 18,
          12,
        ),
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
                        getVehiculoDisplayName(
                          mantenimiento.vehiculoId,
                          fallback: mantenimiento.vehiculoLabel,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tipo?.nombre ?? 'Sin tipo',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                buildEstadoTag(detalle.estadoActual),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (mantenimiento.fechaSugerida != null)
                  buildInfoBadge(
                    Icons.calendar_month,
                    'Sugerida ${formatShort(mantenimiento.fechaSugerida)}',
                  ),
                if (mantenimiento.fechaProgramada != null)
                  buildInfoBadge(
                    Icons.event_available,
                    'Programada ${formatShort(mantenimiento.fechaProgramada)}',
                  ),
                if (mantenimiento.fechaRealizada != null)
                  buildInfoBadge(
                    Icons.done_all,
                    'Realizada ${formatShort(mantenimiento.fechaRealizada)}',
                  ),
                if (mantenimiento.costo > 0)
                  buildInfoBadge(
                    Icons.attach_money,
                    NumberFormat.simpleCurrency(
                      locale: 'es_CO',
                    ).format(mantenimiento.costo),
                  ),
                if (mantenimiento.prioridad.isNotEmpty)
                  buildInfoBadge(
                    Icons.flag,
                    'Prioridad ${priorityLabel(mantenimiento.prioridad)}',
                    color: priorityColor(mantenimiento.prioridad),
                  ),
                if (mantenimiento.taller.trim().isNotEmpty)
                  buildInfoBadge(
                    Icons.store_mall_directory,
                    mantenimiento.taller,
                  ),
              ],
            ),
            if (mantenimiento.observaciones.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                mantenimiento.observaciones,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 14),
            if (_isConductor || _isPropietario)
              Align(
                alignment: Alignment.centerRight,
                child:
                    ((mantenimiento.estado.toUpperCase() == 'SUGERIDO' ||
                            mantenimiento.estado.toUpperCase() ==
                                'PROGRAMADO') &&
                        usuarioTieneAccesoAlVehiculo(mantenimiento.vehiculoId))
                    ? TextButton(
                        onPressed: () => showCompletarMantenimientoModal(
                          detalle,
                          closeParentAfterAction: closeParentAfterAction,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: _successColor,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          context.t('maintenance.complete'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showMantenimientoDetalleModal(
    _MantenimientoDetalle detalle,
  ) async {
    final mantenimiento = detalle.mantenimiento;
    final tipo = detalle.tipo;

    Widget detailItem(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            MediaQuery.of(ctx).viewInsets.bottom + 14,
          ),
          child: buildFloatingModalShell(
            maxWidth: 540,
            maxHeightFactor: 0.88,
            child: Column(
              children: [
                buildFloatingModalHeader(
                  title: tipo?.nombre ?? 'Mantenimiento',
                  subtitle: getVehiculoDisplayName(
                    mantenimiento.vehiculoId,
                    fallback: mantenimiento.vehiculoLabel,
                  ),
                  icon: Icons.build_rounded,
                  trailing: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: buildEstadoTag(detalle.estadoActual),
                        ),
                        const SizedBox(height: 18),

                        detailItem(
                          Icons.build,
                          'Tipo de mantenimiento',
                          tipo?.nombre ?? 'Sin tipo',
                        ),

                        detailItem(
                          Icons.person,
                          'Propietario',
                          mantenimiento.propietarioNombre,
                        ),

                        if (mantenimiento.conductorNombre.isNotEmpty)
                          detailItem(
                            Icons.drive_eta,
                            'Conductor',
                            mantenimiento.conductorNombre,
                          ),

                        if (mantenimiento.fechaSugerida != null)
                          detailItem(
                            Icons.lightbulb,
                            'Fecha sugerida',
                            formatShort(mantenimiento.fechaSugerida),
                          ),

                        if (mantenimiento.fechaProgramada != null)
                          detailItem(
                            Icons.event_available,
                            'Fecha programada',
                            formatShort(mantenimiento.fechaProgramada),
                          ),

                        if (mantenimiento.fechaRealizada != null)
                          detailItem(
                            Icons.done_all,
                            'Fecha realizada',
                            formatShort(mantenimiento.fechaRealizada),
                          ),

                        if (mantenimiento.kilometraje > 0)
                          detailItem(
                            Icons.speed,
                            'Kilometraje',
                            '${mantenimiento.kilometraje} km',
                          ),

                        if (mantenimiento.costo > 0)
                          detailItem(
                            Icons.attach_money,
                            'Costo',
                            NumberFormat.simpleCurrency(
                              locale: 'es_CO',
                            ).format(mantenimiento.costo),
                          ),

                        if (mantenimiento.taller.trim().isNotEmpty)
                          detailItem(
                            Icons.store_mall_directory,
                            'Taller',
                            mantenimiento.taller,
                          ),

                        detailItem(
                          Icons.flag,
                          'Prioridad',
                          priorityLabel(mantenimiento.prioridad),
                        ),

                        detailItem(
                          Icons.notes,
                          'Observaciones',
                          mantenimiento.observaciones.trim().isEmpty
                              ? 'No tiene observaciones'
                              : mantenimiento.observaciones.trim(),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(context.t('maintenance.close')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildInfoBadge(IconData icon, String label, {Color? color}) {
    final badgeColor = color ?? Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget buildEstadoTag(String estado) {
    final Color color = statusColor(estado);
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
            statusLabel(estado),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration modalInputDecoration({
    required String label,
    String? errorText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      errorText: errorText,
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _accentColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _dangerColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _dangerColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget modalSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _accentColor, size: 19),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showNewMaintenanceModal() async {
    final TextEditingController tallerController = TextEditingController();
    final TextEditingController observacionesController =
        TextEditingController();
    final TextEditingController costoController = TextEditingController();
    final TextEditingController kilometrajeController = TextEditingController();

    DateTime? fechaSugerida;
    DateTime? fechaProgramada;
    DateTime? fechaRealizada;
    String? selectedVehiculo;
    String? selectedTipo;
    String selectedPrioridad = 'Media';
    String selectedModo = 'Sugerido';
    String? errorText;
    bool isClosing = false;

    final List<String> vehiculos = availableVehiculos();
    final List<String> tipos = availableTipos();

    Future<DateTime?> selectDate(BuildContext ctx, DateTime? current) async {
      final DateTime now = DateTime.now();
      return showDatePicker(
        context: ctx,
        initialDate: current ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2),
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accentColor,
                onPrimary: Colors.white,
                surface: Color(0xFF1C2140),
                onSurface: Colors.white,
              ),
            ),
            child: child,
          );
        },
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                14,
                14,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: buildFloatingModalShell(
                maxWidth: 560,
                maxHeightFactor: 0.90,
                child: Column(
                  children: [
                    buildFloatingModalHeader(
                      title: context.t('maintenance.create'),
                      subtitle:
                          'Sugiere, programa o registra un mantenimiento.',
                      icon: Icons.build_circle_rounded,
                      trailing: IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            modalSectionTitle(
                              'Información principal',
                              Icons.build_circle,
                            ),

                            DropdownButtonFormField<String>(
                              initialValue: selectedModo,
                              items: [
                                DropdownMenuItem(
                                  value: 'Sugerido',
                                  child: Text(context.t('maintenance.suggested')),
                                ),
                                DropdownMenuItem(
                                  value: 'Programado',
                                  child: Text(context.t('maintenance.scheduled')),
                                ),
                                DropdownMenuItem(
                                  value: 'Realizado',
                                  child: Text(context.t('maintenance.done')),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  selectedModo = value;
                                  if (selectedModo == 'Sugerido') {
                                    kilometrajeController.clear();
                                  }
                                });
                              },
                              dropdownColor: const Color(0xFF151B47),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              decoration: modalInputDecoration(
                                label: 'Tipo de registro',
                              ),
                            ),

                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: selectedVehiculo,
                              items: vehiculos
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() => selectedVehiculo = value);
                              },
                              dropdownColor: const Color(0xFF151B47),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              decoration: modalInputDecoration(
                                label: 'Vehículo',
                              ),
                            ),

                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: selectedTipo,
                              items: tipos
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() => selectedTipo = value);
                              },
                              dropdownColor: const Color(0xFF151B47),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              decoration: modalInputDecoration(
                                label: 'Tipo de mantenimiento',
                              ),
                            ),

                            modalSectionTitle(
                              'Fechas del mantenimiento',
                              Icons.calendar_month,
                            ),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final DateTime? picked = await selectDate(
                                    ctx,
                                    selectedModo == 'Sugerido'
                                        ? fechaSugerida
                                        : selectedModo == 'Programado'
                                        ? fechaProgramada
                                        : fechaRealizada,
                                  );

                                  if (picked != null) {
                                    setModalState(() {
                                      if (selectedModo == 'Sugerido') {
                                        fechaSugerida = picked;
                                      } else if (selectedModo == 'Programado') {
                                        fechaProgramada = picked;
                                      } else {
                                        fechaRealizada = picked;
                                      }
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  selectedModo == 'Sugerido'
                                      ? (fechaSugerida == null
                                            ? 'Seleccionar fecha sugerida'
                                            : 'Sugerida ${DateFormat('dd/MM/yyyy').format(fechaSugerida!)}')
                                      : selectedModo == 'Programado'
                                      ? (fechaProgramada == null
                                            ? 'Seleccionar fecha programada'
                                            : 'Programada ${DateFormat('dd/MM/yyyy').format(fechaProgramada!)}')
                                      : (fechaRealizada == null
                                            ? 'Seleccionar fecha realizada'
                                            : 'Realizada ${DateFormat('dd/MM/yyyy').format(fechaRealizada!)}'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),

                            modalSectionTitle('Prioridad', Icons.flag),

                            DropdownButtonFormField<String>(
                              initialValue: selectedPrioridad,
                              items: [
                                DropdownMenuItem(
                                  value: 'Alta',
                                  child: Text(context.t('maintenance.high')),
                                ),
                                DropdownMenuItem(
                                  value: 'Media',
                                  child: Text(context.t('maintenance.medium')),
                                ),
                                DropdownMenuItem(
                                  value: 'Baja',
                                  child: Text(context.t('maintenance.low')),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  selectedPrioridad = value;
                                });
                              },
                              dropdownColor: const Color(0xFF151B47),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              decoration: modalInputDecoration(
                                label: 'Prioridad',
                              ),
                            ),

                            if (selectedModo == 'Realizado') ...[
                              modalSectionTitle(
                                'Datos de realización',
                                Icons.handyman,
                              ),

                              TextField(
                                controller: kilometrajeController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: modalInputDecoration(
                                  label: 'Kilometraje *',
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: tallerController,
                                decoration: modalInputDecoration(
                                  label: 'Taller',
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),

                              const SizedBox(height: 14),

                              TextField(
                                controller: costoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: modalInputDecoration(
                                  label: 'Costo',
                                  prefixText: r'$ ',
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],

                            modalSectionTitle(
                              'Observaciones finales',
                              Icons.notes,
                            ),

                            TextField(
                              controller: observacionesController,
                              maxLines: 3,
                              decoration: modalInputDecoration(
                                label: 'Observaciones',
                                errorText: errorText,
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isClosing
                                        ? null
                                        : () {
                                            setModalState(
                                              () => isClosing = true,
                                            );
                                            Navigator.of(ctx).pop();
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(context.t('common.cancel')),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      setModalState(() {
                                        errorText = null;

                                        if (selectedVehiculo == null ||
                                            selectedVehiculo!.isEmpty) {
                                          errorText = 'Selecciona un vehículo';
                                        } else if (selectedTipo == null ||
                                            selectedTipo!.isEmpty) {
                                          errorText =
                                              'Selecciona tipo de mantenimiento';
                                        } else if (selectedModo == 'Sugerido' &&
                                            fechaSugerida == null) {
                                          errorText =
                                              'Selecciona la fecha sugerida';
                                        } else if (selectedModo ==
                                                'Programado' &&
                                            fechaProgramada == null) {
                                          errorText =
                                              'Selecciona la fecha programada';
                                        } else if (selectedModo ==
                                                'Realizado' &&
                                            fechaRealizada == null) {
                                          errorText =
                                              'Selecciona la fecha de realización';
                                        } else if (selectedModo ==
                                                'Realizado' &&
                                            (kilometrajeController.text
                                                    .trim()
                                                    .isEmpty ||
                                                int.tryParse(
                                                      kilometrajeController.text
                                                          .trim(),
                                                    ) ==
                                                    null)) {
                                          errorText =
                                              'Ingresa el kilometraje válido';
                                        }
                                      });

                                      if (errorText != null) return;

                                      final int vehiculoId =
                                          getVehiculoIdFromSelection(
                                            selectedVehiculo,
                                          );

                                      final int tipoId = getTipoIdFromSelection(
                                        selectedTipo,
                                      );

                                      final int costo =
                                          int.tryParse(
                                            costoController.text.trim(),
                                          ) ??
                                          0;

                                      final int kilometraje =
                                          int.tryParse(
                                            kilometrajeController.text.trim(),
                                          ) ??
                                          0;

                                      final String estado =
                                          selectedModo == 'Sugerido'
                                          ? 'SUGERIDO'
                                          : selectedModo == 'Programado'
                                          ? 'PROGRAMADO'
                                          : 'REALIZADO';

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token = prefs.getString(
                                        'auth_token',
                                      );

                                      final result =
                                          await ApiService.createMantenimiento(
                                            vehiculoId: vehiculoId,
                                            tipoId: tipoId,
                                            estado: estado.trim().toUpperCase(),
                                            fechaSugerida:
                                                selectedModo == 'Sugerido'
                                                ? fechaSugerida
                                                : null,
                                            fechaProgramada:
                                                selectedModo == 'Programado'
                                                ? fechaProgramada
                                                : null,
                                            fechaRealizada:
                                                selectedModo == 'Realizado'
                                                ? fechaRealizada
                                                : null,
                                            kilometraje:
                                                selectedModo == 'Realizado'
                                                ? kilometraje
                                                : null,
                                            costo: selectedModo == 'Realizado'
                                                ? costo
                                                : null,
                                            taller: selectedModo == 'Realizado'
                                                ? tallerController.text.trim()
                                                : null,
                                            observaciones:
                                                observacionesController.text
                                                    .trim(),
                                            prioridad: selectedPrioridad,
                                            token: token,
                                          );

                                      if (result != null) {
                                        if (selectedModo == 'Realizado') {
                                          final int mantenimientoCreadoId =
                                              int.tryParse(
                                                (result['id'] ??
                                                        result['id_mantenimiento'] ??
                                                        '')
                                                    .toString(),
                                              ) ??
                                              0;

                                          if (mantenimientoCreadoId > 0) {
                                            await ApiService.updateMantenimiento(
                                              mantenimientoId:
                                                  mantenimientoCreadoId,
                                              fechaRealizada: fechaRealizada,
                                              kilometraje: kilometraje,
                                              costo: costo,
                                              taller: tallerController.text
                                                  .trim(),
                                              observaciones:
                                                  observacionesController.text
                                                      .trim(),
                                              estado: 'REALIZADO',
                                              token: token,
                                            );
                                          }
                                        }

                                        await _loadData();

                                        if (!ctx.mounted) return;
                                        Navigator.of(ctx).pop();

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✅ Mantenimiento ${selectedModo.toLowerCase()} creado correctamente',
                                            ),
                                          ),
                                        );
                                      } else {
                                        setModalState(
                                          () => errorText =
                                              'Error al crear el mantenimiento',
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check_rounded),
                                    label: Text(context.t('maintenance.create')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _accentColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
    kilometrajeController.dispose();
  }

  Future<void> showCompletarMantenimientoModal(
    _MantenimientoDetalle detalle, {
    bool closeParentAfterAction = false,
  }) async {
    final _Mantenimiento mantenimiento = detalle.mantenimiento;

    // Validar que el usuario tenga acceso al vehículo
    if (!usuarioTieneAccesoAlVehiculo(mantenimiento.vehiculoId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('maintenance.noAccess')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController tallerController = TextEditingController(
      text: mantenimiento.taller,
    );
    final TextEditingController observacionesController = TextEditingController(
      text: mantenimiento.observaciones,
    );
    final TextEditingController costoController = TextEditingController(
      text: mantenimiento.costo > 0 ? mantenimiento.costo.toString() : '',
    );
    final TextEditingController kilometrajeController = TextEditingController(
      text: mantenimiento.kilometraje > 0
          ? mantenimiento.kilometraje.toString()
          : '',
    );

    DateTime? fechaRealizada = mantenimiento.fechaRealizada ?? DateTime.now();
    String? errorText;
    bool isClosing = false;

    Future<DateTime?> selectDate(BuildContext ctx, DateTime? current) async {
      final DateTime now = DateTime.now();
      return showDatePicker(
        context: ctx,
        initialDate: current ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2),
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accentColor,
                onPrimary: Colors.white,
                surface: Color(0xFF1C2140),
                onSurface: Colors.white,
              ),
            ),
            child: child,
          );
        },
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.86,
                ),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                         Text(
                          context.t('maintenance.complete'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${detalle.tipo?.nombre ?? 'Mantenimiento'} - ${getVehiculoDisplayName(mantenimiento.vehiculoId, fallback: mantenimiento.vehiculoLabel)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        modalSectionTitle(
                          'Datos de realización',
                          Icons.check_circle,
                        ),
                        InputDecorator(
                          decoration: modalInputDecoration(
                            label: 'Fecha de realización',
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await selectDate(
                                ctx,
                                fechaRealizada,
                              );
                              if (picked != null) {
                                setModalState(() => fechaRealizada = picked);
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(fechaRealizada ?? DateTime.now()),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: tallerController,
                          decoration: modalInputDecoration(label: 'Taller'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: kilometrajeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: modalInputDecoration(
                            label: 'Kilometraje',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: costoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: modalInputDecoration(
                            label: 'Costo',
                            prefixText: r'$ ',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        modalSectionTitle('Observaciones finales', Icons.notes),
                        TextField(
                          controller: observacionesController,
                          maxLines: 3,
                          decoration: modalInputDecoration(
                            label: 'Observaciones',
                            errorText: errorText,
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isClosing
                                    ? null
                                    : () {
                                        setModalState(() => isClosing = true);
                                        Navigator.of(ctx).pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(context.t('common.cancel')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  setModalState(() {
                                    errorText = null;
                                    if (fechaRealizada == null) {
                                      errorText =
                                          'Selecciona la fecha de realización';
                                    } else if (kilometrajeController.text
                                            .trim()
                                            .isEmpty ||
                                        int.tryParse(
                                              kilometrajeController.text.trim(),
                                            ) ==
                                            null) {
                                      errorText =
                                          'Ingresa el kilometraje válido';
                                    }
                                  });

                                  if (errorText != null) return;

                                  final costo =
                                      int.tryParse(
                                        costoController.text.trim(),
                                      ) ??
                                      0;
                                  final kilometraje =
                                      int.tryParse(
                                        kilometrajeController.text.trim(),
                                      ) ??
                                      0;

                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final token = prefs.getString('auth_token');
                                  final userId =
                                      widget.userId ??
                                      prefs.getString('user_id');

                                  final result =
                                      await ApiService.updateMantenimiento(
                                        mantenimientoId: mantenimiento.id,
                                        fechaRealizada: fechaRealizada,
                                        kilometraje: kilometraje,
                                        costo: costo,
                                        taller: tallerController.text.trim(),
                                        observaciones: observacionesController
                                            .text
                                            .trim(),
                                        estado: null,
                                        userId: userId,
                                        token: token,
                                      );

                                  if (result != null) {
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();

                                    if (closeParentAfterAction && mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    await _loadData(showLoader: false);

                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ Mantenimiento completado correctamente',
                                        ),
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      errorText =
                                          'Error al completar el mantenimiento';
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _successColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(context.t('maintenance.complete')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
    kilometrajeController.dispose();
  }

  Widget buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'No fue posible cargar la informacion.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadData, child: Text(context.t('common.retry'))),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_circle_outlined, color: Colors.white54, size: 48),
          SizedBox(height: 14),
          Text(
            context.t('maintenance.empty'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            context.t('maintenance.emptyHelp'),
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String normalizeStatus(String value) => value.toUpperCase();

  String formatShort(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }
    return DateFormat('dd/MM/yyyy').format(value.toLocal());
  }

  String statusLabel(String value) {
    final String normalized = normalizeStatus(value);
    switch (normalized) {
      case 'SUGERIDO':
        return context.t('maintenance.suggested');
      case 'PROGRAMADO':
        return context.t('maintenance.scheduled');
      case 'EN_PROCESO':
        return 'En proceso';
      case 'REALIZADO':
        return context.t('maintenance.done');
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return normalized[0].toUpperCase() +
            normalized.substring(1).toLowerCase();
    }
  }

  String priorityLabel(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'alta') return context.t('maintenance.high');
    if (normalized == 'media') return context.t('maintenance.medium');
    if (normalized == 'baja') return context.t('maintenance.low');

    return value.trim().isEmpty ? context.t('maintenance.medium') : value.trim();
  }

  Color priorityColor(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'alta') return _dangerColor;
    if (normalized == 'media') return _warningColor;
    if (normalized == 'baja') return _successColor;

    return _warningColor;
  }

  int priorityRank(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'alta') return 0;
    if (normalized == 'media') return 1;
    if (normalized == 'baja') return 2;

    return 1;
  }

  Color statusColor(String value) {
    final String normalized = normalizeStatus(value);
    switch (normalized) {
      case 'REALIZADO':
        return _infoColor; // Azul para finalizados
      case 'EN_PROCESO':
      case 'PROGRAMADO':
      case 'SUGERIDO':
        return _warningColor; // Naranja para programados/sugeridos
      case 'CANCELADO':
        return _dangerColor;
      default:
        return _accentColor;
    }
  }
}
