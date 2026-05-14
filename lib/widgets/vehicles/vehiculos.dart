import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/services/api_service.dart';
import 'package:trackfile/utils/api_config.dart';
import 'package:trackfile/widgets/utils/shimmer_skeleton.dart';

/// Visualiza los registros de la tabla vehiculos con filtros basados en estado y busqueda.
class VehiculosWidget extends StatefulWidget {
  final String role;
  final String? ownerId;
  final String? jsonPath;
  final String? personaUserId;
  final String? personaTipo;
  final String? personaNombre;
  final bool showOwnerColumn;

  final void Function({required int vehiculoId, required String placa})?
  onVerDocumentosVehiculo;

  final void Function({required int vehiculoId, required String placa})?
  onVerMantenimientosVehiculo;

  final void Function({required int propietarioId})? onVerPropietario;

  final void Function({required int conductorId})? onVerConductor;

  const VehiculosWidget({
    super.key,
    required this.role,
    this.ownerId,
    this.jsonPath,
    this.personaUserId,
    this.personaTipo,
    this.personaNombre,
    this.showOwnerColumn = false,
    this.onVerDocumentosVehiculo,
    this.onVerMantenimientosVehiculo,
    this.onVerPropietario,
    this.onVerConductor,
  });

  @override
  State<VehiculosWidget> createState() => _VehiculosWidgetState();
}

class _Vehicle {
  final int idVehiculo;
  final int idPropietario;
  final int? idConductor;
  final String placa;
  final String? vin;
  final String marca;
  final String modelo;
  final int? anio;
  final String? color;
  final int kilometrajeActual;
  final String estadoVehiculo;
  final DateTime? fechaCreacion;
  final String? nombrePropietario;
  final String? nombreConductor;
  // Información del Propietario
  final String? telefonoPropietario;
  final String? emailPropietario;
  final String? documentoPropietario;
  final String? direccionPropietario;
  final String? tipoDocumentoPropietario;
  final String? apellidoPropietario;
  // Información del Conductor
  final String? telefonoConductor;
  final String? emailConductor;
  final String? licenciaConductor;
  final String? categoriaConductor;
  final String? direccionConductor;
  final String? tipoDocumentoConductor;
  final String? documentoConductor;
  final String? apellidoConductor;
  final DateTime? fechaVencimientoLicencia;
  // Documentos
  final List<Map<String, dynamic>> documentosVehiculo;
  final int cantidadDocumentosVigentes;

  const _Vehicle({
    required this.idVehiculo,
    required this.idPropietario,
    this.idConductor,
    required this.placa,
    required this.vin,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.color,
    required this.kilometrajeActual,
    required this.estadoVehiculo,
    required this.fechaCreacion,
    this.nombrePropietario,
    this.nombreConductor,
    this.telefonoPropietario,
    this.emailPropietario,
    this.documentoPropietario,
    this.direccionPropietario,
    this.tipoDocumentoPropietario,
    this.apellidoPropietario,
    this.telefonoConductor,
    this.emailConductor,
    this.licenciaConductor,
    this.categoriaConductor,
    this.direccionConductor,
    this.tipoDocumentoConductor,
    this.documentoConductor,
    this.apellidoConductor,
    this.fechaVencimientoLicencia,
    this.documentosVehiculo = const [],
    this.cantidadDocumentosVigentes = 0,
  });

  String get statusKey => estadoVehiculo.toUpperCase();
}

class _VehiculosWidgetState extends State<VehiculosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);

  bool _isLoading = true;
  List<_Vehicle> _vehicles = const [];
  final Map<int, Map<String, dynamic>> _propietariosMap = {};
  final Map<int, Map<String, dynamic>> _conductoresMap = {};
  String? _statusFilter;
  String _searchTerm = '';
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String _baseUrl = ApiConfig.fallbackBaseUrl();
  String? _error;
  bool get _viendoPersona =>
      widget.personaUserId != null && widget.personaUserId!.isNotEmpty;

  String get _role => widget.role.toLowerCase().trim();

  bool get _isEmpresaLike =>
      _role == 'empresa' || _role == 'admin' || _role == 'secretaria';

  bool get _isPropietario => _role == 'propietario';
  bool get _isConductor => _role == 'conductor';
  bool get _canCreateVehicle => _isEmpresaLike;
  bool get _canEditVehicleInfo => _isEmpresaLike;
  bool get _canManageDriverAssignment => _isEmpresaLike || _isPropietario;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initBaseUrl();
    await _loadAllData(showLoader: false);
  }

  Future<void> _loadAllData({bool showLoader = true}) async {
    await Future.wait([_loadPropietariosFromApi(), _loadConductoresFromApi()]);

    await _loadVehicles(showLoader: showLoader);
  }

  Future<void> _initBaseUrl() async {
    final resolved = await ApiConfig.loadBaseUrl();
    if (!mounted) return;
    _baseUrl = resolved;
  }

  Future<void> _loadPropietariosFromApi() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      if (token == null) return;

      final uri = ApiConfig.resolve(_baseUrl, '/api/propietarios');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _propietariosMap.clear();

        for (final prop in data.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse(
            prop['id']?.toString() ?? prop['idPropietario']?.toString() ?? '',
          );
          final nombre = prop['nombre']?.toString() ?? 'Desconocido';
          if (id != null) {
            _propietariosMap[id] = {...prop, 'nombre': nombre};
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando propietarios: $e');
    }
  }

  Future<void> _loadConductoresFromApi() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      if (token == null) return;

      final uri = ApiConfig.resolve(_baseUrl, '/api/conductores');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _conductoresMap.clear();

        for (final cond in data.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse(
            cond['id']?.toString() ?? cond['idConductor']?.toString() ?? '',
          );
          final nombre = cond['nombre']?.toString() ?? 'Desconocido';
          if (id != null) {
            _conductoresMap[id] = {...cond, 'nombre': nombre};
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando conductores: $e');
    }
  }

  Future<void> _loadVehicles({bool showLoader = true}) async {
    try {
      if (showLoader) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Obtener token de SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }


      final uri = ApiConfig.resolve(_baseUrl, '/api/vehiculos');

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<_Vehicle> vehicles = _parseVehiclesFromApi(data);

        final List<_Vehicle> vehiclesWithDocuments = _enrichVehiclesWithNames(
          vehicles,
        );

        vehiclesWithDocuments.sort((a, b) => a.placa.compareTo(b.placa));

        setState(() {
          _vehicles = vehiclesWithDocuments;
          _isLoading = false;
        });

      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver los vehículos.');
      } else if (response.statusCode == 404) {
        throw Exception('No se encontraron vehículos para este usuario.');
      } else {
        throw Exception(
          'Error ${response.statusCode}: No se pudieron cargar los vehículos',
        );
      }
    } catch (e) {
      debugPrint('❌ Error cargando vehículos: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _vehicles = [];
      });
    }
  }

  Future<_Vehicle> _loadVehicleDetail(_Vehicle vehicle, String token) async {
    try {
      final uri = ApiConfig.resolve(
        _baseUrl,
        '/api/vehiculos/${vehicle.idVehiculo}/detalle',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;

        return _enrichVehicleFromDetalle(vehicle, data);
      } else {
        debugPrint(
          '⚠️ Error ${response.statusCode} cargando detalle ${vehicle.idVehiculo}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error cargando detalle de vehículo ${vehicle.idVehiculo}: $e',
      );
    }
    return vehicle;
  }

  Future<_Vehicle> _getVehicleDetailOnDemand(_Vehicle vehicle) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return vehicle;
      }

      final detailedVehicle = await _loadVehicleDetail(vehicle, token);

      if (!mounted) return detailedVehicle;

      setState(() {
        _vehicles = _vehicles.map((item) {
          if (item.idVehiculo == detailedVehicle.idVehiculo) {
            return detailedVehicle;
          }
          return item;
        }).toList();
      });

      return detailedVehicle;
    } catch (e) {
      debugPrint('❌ Error cargando detalle bajo demanda: $e');
      return vehicle;
    }
  }

  _Vehicle _enrichVehicleFromDetalle(
    _Vehicle vehicle,
    Map<String, dynamic> data,
  ) {
    // Información del Propietario
    String? nombreProp = vehicle.nombrePropietario;
    String? telProp;
    String? emailProp;
    String? docProp;

    // Intentar extraer desde estructura anidada: propietario.usuario
    final propietario = data['propietario'] as Map<String, dynamic>?;
    if (propietario != null) {
      // Si viene como objeto completo
      if (propietario['usuario'] is Map<String, dynamic>) {
        final usuario = propietario['usuario'] as Map<String, dynamic>;
        nombreProp =
            nombreProp ??
            '${usuario['nombre']?.toString() ?? ''} ${usuario['apellido']?.toString() ?? ''}'
                .trim();
        telProp = usuario['telefono']?.toString();
        emailProp = usuario['correo']?.toString();
      } else if (propietario['nombre'] != null) {
        // Si viene como objeto simplificado
        nombreProp = nombreProp ?? propietario['nombre']?.toString();
        telProp = propietario['telefono']?.toString();
        emailProp = propietario['correo']?.toString();
      }
      // Buscar documento en varias ubicaciones
      docProp = propietario['documentoPropietario']?.toString();
      if (docProp == null || docProp.isEmpty) {
        docProp = propietario['numeroDocumento']?.toString();
      }
      if (docProp == null || docProp.isEmpty) {
        docProp = propietario['documento']?.toString();
      }
      // Si el usuario tiene documento, usarlo
      if ((docProp == null || docProp.isEmpty) &&
          propietario['usuario'] is Map<String, dynamic>) {
        final usuario = propietario['usuario'] as Map<String, dynamic>;
        docProp = usuario['numeroDocumento']?.toString();
      }
    }

    // Intentar extraer desde campos top-level (alternativa)
    if ((nombreProp == null || nombreProp.isEmpty)) {
      nombreProp = data['nombrePropietario']?.toString();
      if (nombreProp == null || nombreProp.isEmpty) {
        nombreProp =
            '${data['apellidoPropietario']?.toString() ?? ''} ${data['nombrePropietario']?.toString() ?? ''}'
                .trim();
      }
    }
    if (telProp == null || telProp.isEmpty) {
      telProp = data['telefonoPropietario']?.toString();
    }
    if (emailProp == null || emailProp.isEmpty) {
      emailProp = data['emailPropietario']?.toString();
    }
    if (docProp == null || docProp.isEmpty) {
      docProp = data['documentoPropietario']?.toString();
    }
    if (docProp == null || docProp.isEmpty) {
      docProp = data['numeroCedulaPropietario']?.toString();
    }

    // Información del Conductor
    String? nombreCond = vehicle.nombreConductor;
    String? telCond;
    String? emailCond;
    String? licenciaCond;
    String? categoriaCond;
    DateTime? fechaVencimientoLic;

    // Intentar extraer desde estructura anidada: conductor.usuario
    final conductor = data['conductor'] as Map<String, dynamic>?;
    if (conductor != null) {
      // Si viene como objeto completo
      if (conductor['usuario'] is Map<String, dynamic>) {
        final usuario = conductor['usuario'] as Map<String, dynamic>;
        nombreCond =
            nombreCond ??
            '${usuario['nombre']?.toString() ?? ''} ${usuario['apellido']?.toString() ?? ''}'
                .trim();
        telCond = usuario['telefono']?.toString();
        emailCond = usuario['correo']?.toString();
      } else if (conductor['nombre'] != null) {
        // Si viene como objeto simplificado
        nombreCond = nombreCond ?? conductor['nombre']?.toString();
        telCond = conductor['telefono']?.toString();
        emailCond = conductor['correo']?.toString();
      }
      licenciaCond = conductor['licenciaConduccion']?.toString();
      categoriaCond = conductor['categoriaLicencia']?.toString();
      final fechaVenc = conductor['fechaVencimientoLicencia']?.toString();
      if (fechaVenc != null && fechaVenc.isNotEmpty) {
        fechaVencimientoLic = DateTime.tryParse(fechaVenc);
      }
    }

    // Intentar extraer desde campos top-level (alternativa)
    if ((nombreCond == null || nombreCond.isEmpty)) {
      nombreCond = data['nombreConductor']?.toString();
      if (nombreCond == null || nombreCond.isEmpty) {
        nombreCond =
            '${data['apellidoConductor']?.toString() ?? ''} ${data['nombreConductor']?.toString() ?? ''}'
                .trim();
      }
    }
    if (telCond == null || telCond.isEmpty) {
      telCond = data['telefonoConductor']?.toString();
    }
    if (emailCond == null || emailCond.isEmpty) {
      emailCond = data['emailConductor']?.toString();
    }
    if (licenciaCond == null || licenciaCond.isEmpty) {
      licenciaCond = data['licenciaConductor']?.toString();
    }
    if (categoriaCond == null || categoriaCond.isEmpty) {
      categoriaCond = data['categoriaConductor']?.toString();
    }
    if (fechaVencimientoLic == null) {
      final fecha = data['fechaVencimientoLicencia']?.toString();
      if (fecha != null && fecha.isNotEmpty) {
        fechaVencimientoLic = DateTime.tryParse(fecha);
      }
    }

    // Extraer documentos del detalle si vienen en la respuesta
    List<Map<String, dynamic>> documentsFromDetail = [];
    if (data['documentos'] is List) {
      documentsFromDetail = (data['documentos'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return _Vehicle(
      idVehiculo: vehicle.idVehiculo,
      idPropietario: vehicle.idPropietario,
      idConductor: vehicle.idConductor,
      placa: vehicle.placa,
      vin: vehicle.vin,
      marca: vehicle.marca,
      modelo: vehicle.modelo,
      anio: vehicle.anio,
      color: vehicle.color,
      kilometrajeActual: vehicle.kilometrajeActual,
      estadoVehiculo: vehicle.estadoVehiculo,
      fechaCreacion: vehicle.fechaCreacion,
      nombrePropietario: nombreProp,
      nombreConductor: nombreCond,
      telefonoPropietario: telProp,
      emailPropietario: emailProp,
      documentoPropietario: docProp,

      telefonoConductor: telCond,
      emailConductor: emailCond,
      licenciaConductor: licenciaCond,
      categoriaConductor: categoriaCond,
      fechaVencimientoLicencia: fechaVencimientoLic,
      documentosVehiculo: documentsFromDetail.isNotEmpty
          ? documentsFromDetail
          : vehicle.documentosVehiculo,
      cantidadDocumentosVigentes: vehicle.cantidadDocumentosVigentes,
    );
  }

  List<_Vehicle> _parseVehiclesFromApi(List<dynamic> data) {
    return data
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) return null;

          final Map<String, dynamic> map = item;
          final int? id = int.tryParse(
            map['id']?.toString() ?? map['idVehiculo']?.toString() ?? '',
          );
          final int? ownerId = int.tryParse(
            map['idPropietario']?.toString() ??
                map['propietarioId']?.toString() ??
                map['id_propietario']?.toString() ??
                map['propietario']?['id']?.toString() ??
                map['propietario']?['idPropietario']?.toString() ??
                '',
          );

          if (id == null) return null;

          final int kilometraje =
              int.tryParse(map['kilometrajeActual']?.toString() ?? '') ?? 0;
          final int? anio = int.tryParse(map['anio']?.toString() ?? '');
          final DateTime? fecha = DateTime.tryParse(
            map['fechaCreacion']?.toString() ?? '',
          );

          return _Vehicle(
            idVehiculo: id,
            idPropietario: ownerId ?? 0,
            idConductor: int.tryParse(
              map['idConductor']?.toString() ??
                  map['conductorId']?.toString() ??
                  map['id_conductor']?.toString() ??
                  map['conductor']?['id']?.toString() ??
                  map['conductor']?['idConductor']?.toString() ??
                  '',
            ),
            placa: map['placa']?.toString() ?? 'SIN PLACA',
            vin: map['vin']?.toString(),
            marca: map['marca']?.toString() ?? 'Marca desconocida',
            modelo: map['modelo']?.toString() ?? 'Modelo desconocido',
            anio: anio,
            color: map['color']?.toString(),
            kilometrajeActual: kilometraje,
            estadoVehiculo: map['estadoVehiculo']?.toString() ?? 'ACTIVO',
            fechaCreacion: fecha,
            nombrePropietario:
                map['nombrePropietario']?.toString() ??
                map['propietario']?['nombre']?.toString() ??
                map['propietario']?['usuario']?['nombre']?.toString(),

            nombreConductor:
                map['nombreConductor']?.toString() ??
                map['conductor']?['nombre']?.toString() ??
                map['conductor']?['usuario']?['nombre']?.toString(),
          );
        })
        .whereType<_Vehicle>()
        .toList();
  }

  List<_Vehicle> _enrichVehiclesWithNames(List<_Vehicle> vehicles) {
    return vehicles.map((vehicle) {
      String? nombreProp = vehicle.nombrePropietario;
      String? nombreCond = vehicle.nombreConductor;

      final propData = _propietariosMap[vehicle.idPropietario];
      final condData = vehicle.idConductor != null
          ? _conductoresMap[vehicle.idConductor]
          : null;

      // Si no tiene nombre de propietario, intenta obtenerlo del mapa
      if ((nombreProp == null || nombreProp.isEmpty) &&
          vehicle.idPropietario > 0) {
        nombreProp = _propietariosMap[vehicle.idPropietario]?['nombre']
            ?.toString();
      }

      if ((nombreCond == null || nombreCond.isEmpty) &&
          vehicle.idConductor != null) {
        nombreCond = _conductoresMap[vehicle.idConductor]?['nombre']
            ?.toString();
      }

      return _Vehicle(
        idVehiculo: vehicle.idVehiculo,
        idPropietario: vehicle.idPropietario,
        idConductor: vehicle.idConductor,
        placa: vehicle.placa,
        vin: vehicle.vin,
        marca: vehicle.marca,
        modelo: vehicle.modelo,
        anio: vehicle.anio,
        color: vehicle.color,
        kilometrajeActual: vehicle.kilometrajeActual,
        estadoVehiculo: vehicle.estadoVehiculo,
        fechaCreacion: vehicle.fechaCreacion,
        nombrePropietario: nombreProp,
        nombreConductor: nombreCond,
        telefonoPropietario:
            vehicle.telefonoPropietario ?? propData?['telefono']?.toString(),

        emailPropietario:
            vehicle.emailPropietario ?? propData?['correo']?.toString(),

        documentoPropietario:
            vehicle.documentoPropietario ??
            propData?['numeroDocumento']?.toString() ??
            propData?['documentoPropietario']?.toString(),

        direccionPropietario: propData?['direccion']?.toString(),
        tipoDocumentoPropietario: propData?['tipoDocumento']?.toString(),
        apellidoPropietario: propData?['apellido']?.toString(),

        telefonoConductor:
            vehicle.telefonoConductor ?? condData?['telefono']?.toString(),

        emailConductor:
            vehicle.emailConductor ?? condData?['correo']?.toString(),

        licenciaConductor:
            vehicle.licenciaConductor ??
            condData?['licenciaConduccion']?.toString(),

        categoriaConductor:
            vehicle.categoriaConductor ??
            condData?['categoriaLicencia']?.toString(),
        direccionConductor: condData?['direccion']?.toString(),
        tipoDocumentoConductor: condData?['tipoDocumento']?.toString(),
        documentoConductor: condData?['numeroDocumento']?.toString(),
        apellidoConductor: condData?['apellido']?.toString(),
        fechaVencimientoLicencia: vehicle.fechaVencimientoLicencia,
        documentosVehiculo: vehicle.documentosVehiculo,
        cantidadDocumentosVigentes: vehicle.cantidadDocumentosVigentes,
      );
    }).toList();
  }

  List<_Vehicle> get _filteredVehicles {
    Iterable<_Vehicle> filtered = _vehiclesForCurrentUser;

    if (_statusFilter != null) {
      final String normalized = _statusFilter!;
      filtered = filtered.where((vehicle) => vehicle.statusKey == normalized);
    }

    if (_searchTerm.isNotEmpty) {
      final String lower = _searchTerm.toLowerCase();
      filtered = filtered.where((vehicle) {
        return vehicle.placa.toLowerCase().contains(lower) ||
            vehicle.marca.toLowerCase().contains(lower) ||
            vehicle.modelo.toLowerCase().contains(lower);
      });
    }

    final result = filtered.toList();

    result.sort((a, b) {
      final int aRank = _statusOrderRank(a.statusKey);
      final int bRank = _statusOrderRank(b.statusKey);

      if (aRank != bRank) return aRank.compareTo(bRank);

      return a.placa.compareTo(b.placa);
    });

    return result;
  }

  bool _vehicleMatchesPersona(_Vehicle vehicle) {
    final selectedUserId = widget.personaUserId?.trim() ?? '';
    final selectedTipo = widget.personaTipo?.toUpperCase().trim() ?? '';

    if (selectedUserId.isEmpty) return false;

    if (selectedTipo == 'PROPIETARIO') {
      final propData = _propietariosMap[vehicle.idPropietario];

      final usuarioId = _usuarioIdFromMap(propData);

      return usuarioId == selectedUserId ||
          vehicle.idPropietario.toString() == selectedUserId;
    }

    if (selectedTipo == 'CONDUCTOR') {
      if (vehicle.idConductor == null) return false;

      final condData = _conductoresMap[vehicle.idConductor];

      final usuarioId = _usuarioIdFromMap(condData);

      return usuarioId == selectedUserId ||
          vehicle.idConductor.toString() == selectedUserId;
    }

    return false;
  }

  String _usuarioIdFromMap(Map<String, dynamic>? data) {
    if (data == null) return '';

    final usuario = data['usuario'];

    if (usuario is Map) {
      return usuario['id']?.toString() ??
          usuario['idUsuario']?.toString() ??
          usuario['id_usuario']?.toString() ??
          '';
    }

    return data['usuarioId']?.toString() ??
        data['idUsuario']?.toString() ??
        data['id_usuario']?.toString() ??
        '';
  }

  int? _currentEntityIdByRole() {
    final rawId = widget.ownerId?.trim() ?? '';
    if (rawId.isEmpty) return null;

    final directId = int.tryParse(rawId);

    if (_isPropietario) {
      for (final entry in _propietariosMap.entries) {
        final usuarioId = _usuarioIdFromMap(entry.value);
        if (usuarioId == rawId) return entry.key;
      }
      return directId;
    }

    if (_isConductor) {
      for (final entry in _conductoresMap.entries) {
        final usuarioId = _usuarioIdFromMap(entry.value);
        if (usuarioId == rawId) return entry.key;
      }
      return directId;
    }

    return directId;
  }

  void _setStatusFilter(String status) {
    final String normalized = status.toUpperCase();
    setState(() {
      _statusFilter = _statusFilter == normalized ? null : normalized;
    });
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _searchTerm = '';
    });

  }

  Widget _buildVehicleTopActions(bool isCompact) {
    if (!_canCreateVehicle) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 14 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gestiona la flota, propietarios y conductores asignados.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isCompact ? 11 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showCreateVehicleModal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    isCompact ? 'Crear' : 'Crear vehículo',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 18,
                      vertical: isCompact ? 10 : 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateVehicleModal() {
    final placaCtrl = TextEditingController();
    final vinCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final anioCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final kmCtrl = TextEditingController();

    int? selectedPropietarioId = _propietariosMap.keys.isNotEmpty
        ? _propietariosMap.keys.first
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF151B47),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
                padding: const EdgeInsets.all(22),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModalHeader(
                        title: 'Crear vehículo',
                        subtitle: 'Registra un vehículo nuevo en la flota.',
                        icon: Icons.add_road_rounded,
                      ),
                      const SizedBox(height: 18),

                      _buildOwnerDropdown(selectedPropietarioId, (value) {
                        setModalState(() => selectedPropietarioId = value);
                      }),

                      const SizedBox(height: 12),
                      _buildModalInput('Placa', placaCtrl),
                      _buildModalInput('VIN', vinCtrl),
                      _buildModalInput('Marca', marcaCtrl),
                      _buildModalInput('Modelo', modeloCtrl),
                      _buildModalInput('Año', anioCtrl, isNumber: true),
                      _buildModalInput('Color', colorCtrl),
                      _buildModalInput(
                        'Kilometraje actual',
                        kmCtrl,
                        isNumber: true,
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                if (selectedPropietarioId == null) return;

                                final creado = await ApiService.createVehiculo(
                                  idPropietario: selectedPropietarioId!,
                                  placa: placaCtrl.text,
                                  vin: vinCtrl.text,
                                  marca: marcaCtrl.text,
                                  modelo: modeloCtrl.text,
                                  anio: int.tryParse(anioCtrl.text) ?? 0,
                                  color: colorCtrl.text,
                                  kilometrajeActual:
                                      int.tryParse(kmCtrl.text) ?? 0,
                                );

                                if (!mounted) return;
                                navigator.pop();

                                await _loadAllData(showLoader: false);

                                if (!mounted) return;

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      creado != null
                                          ? 'Vehículo creado correctamente'
                                          : 'No se pudo crear el vehículo',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditVehicleModal(_Vehicle vehicle) {
    final placaCtrl = TextEditingController(text: vehicle.placa);
    final vinCtrl = TextEditingController(text: vehicle.vin ?? '');
    final marcaCtrl = TextEditingController(text: vehicle.marca);
    final modeloCtrl = TextEditingController(text: vehicle.modelo);
    final anioCtrl = TextEditingController(
      text: vehicle.anio?.toString() ?? '',
    );
    final colorCtrl = TextEditingController(text: vehicle.color ?? '');
    final kmCtrl = TextEditingController(
      text: vehicle.kilometrajeActual.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModalHeader(
                    title: 'Editar vehículo',
                    subtitle: 'Actualiza los datos principales del vehículo.',
                    icon: Icons.edit_road_rounded,
                  ),
                  const SizedBox(height: 18),
                  _buildModalInput('Placa', placaCtrl),
                  _buildModalInput('VIN', vinCtrl),
                  _buildModalInput('Marca', marcaCtrl),
                  _buildModalInput('Modelo', modeloCtrl),
                  _buildModalInput('Año', anioCtrl, isNumber: true),
                  _buildModalInput('Color', colorCtrl),
                  _buildModalInput(
                    'Kilometraje actual',
                    kmCtrl,
                    isNumber: true,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final actualizado = await ApiService.updateVehiculo(
                              vehiculoId: vehicle.idVehiculo,
                              placa: placaCtrl.text,
                              vin: vinCtrl.text,
                              marca: marcaCtrl.text,
                              modelo: modeloCtrl.text,
                              anio: int.tryParse(anioCtrl.text),
                              color: colorCtrl.text,
                              kilometrajeActual: int.tryParse(kmCtrl.text),
                            );

                            if (!mounted) return;
                            navigator.pop();

                            await _loadAllData(showLoader: false);

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  actualizado != null
                                      ? 'Vehículo actualizado correctamente'
                                      : 'No se pudo actualizar el vehículo',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Guardar cambios'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAssignDriverModal(_Vehicle vehicle) {
    int? selectedConductorId = _conductoresMap.keys.isNotEmpty
        ? _conductoresMap.keys.first
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF151B47),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModalHeader(
                      title: 'Asignar conductor',
                      subtitle:
                          'Selecciona el conductor para ${vehicle.placa}.',
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                    const SizedBox(height: 18),
                    _buildDriverDropdown(selectedConductorId, (value) {
                      setModalState(() => selectedConductorId = value);
                    }),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              final actualizado =
                                  await ApiService.asignarConductorVehiculo(
                                    vehiculoId: vehicle.idVehiculo,
                                    idConductor: selectedConductorId!,
                                  );

                              if (!mounted) return;
                              navigator.pop();

                              await _loadAllData(showLoader: false);

                              if (!mounted) return;

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    actualizado != null
                                        ? 'Conductor asignado correctamente'
                                        : 'No se pudo asignar el conductor',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Asignar'),
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
  }

  Widget _buildModalHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildModalInput(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerDropdown(int? selectedValue, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: selectedValue,
        dropdownColor: const Color(0xFF151B47),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Propietario',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: _propietariosMap.entries.map((entry) {
          return DropdownMenuItem<int>(
            value: entry.key,
            child: Text(
              entry.value['nombre']?.toString() ?? 'Propietario ${entry.key}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDriverDropdown(
    int? selectedValue,
    ValueChanged<int?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: selectedValue,
        dropdownColor: const Color(0xFF151B47),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Conductor',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: _conductoresMap.entries.map((entry) {
          return DropdownMenuItem<int>(
            value: entry.key,
            child: Text(
              entry.value['nombre']?.toString() ?? 'Conductor ${entry.key}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Map<String, int> get _statusCounts {
    final Map<String, int> counts = <String, int>{};

    for (final _Vehicle vehicle in _vehiclesForCurrentUser) {
      counts.update(vehicle.statusKey, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts;
  }

  List<_Vehicle> get _vehiclesForCurrentUser {
    Iterable<_Vehicle> filtered = _vehicles;

    if (_viendoPersona) {
      filtered = filtered.where(_vehicleMatchesPersona);
    } else if (widget.ownerId != null && widget.ownerId!.isNotEmpty) {
      final int? currentId = _currentEntityIdByRole();

      if (currentId != null) {
        if (_isPropietario) {
          filtered = filtered.where(
            (vehicle) => vehicle.idPropietario == currentId,
          );
        } else if (_isConductor) {
          filtered = filtered.where(
            (vehicle) => vehicle.idConductor == currentId,
          );
        }
      }
    }

    final result = filtered.toList();

    result.sort((a, b) {
      final int aRank = _statusOrderRank(a.statusKey);
      final int bRank = _statusOrderRank(b.statusKey);

      if (aRank != bRank) return aRank.compareTo(bRank);

      return a.placa.compareTo(b.placa);
    });

    return result;
  }

  int _statusOrderRank(String status) {
    final normalized = status.toUpperCase();

    if (normalized == 'ACTIVO') return 0;

    if (normalized == 'MANTENIMIENTO' ||
        normalized == 'MANTENIMIENTO PROGRAMADO') {
      return 1;
    }

    if (normalized == 'INACTIVO' || normalized == 'FUERA DE SERVICIO') {
      return 2;
    }

    return 3;
  }

  Color _statusColor(String status) {
    final String normalized = status.toUpperCase();
    if (normalized == 'ACTIVO') {
      return _successColor;
    }
    if (normalized == 'MANTENIMIENTO' ||
        normalized == 'MANTENIMIENTO PROGRAMADO') {
      return _warningColor;
    }
    if (normalized == 'INACTIVO' || normalized == 'FUERA DE SERVICIO') {
      return _dangerColor;
    }
    return _accentColor;
  }

  String _statusLabel(String status) {
    if (status.isEmpty) {
      return 'Desconocido';
    }
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Future<void> _desasignarConductor(_Vehicle vehicle) async {
    final actualizado = await ApiService.desasignarConductorVehiculo(
      vehiculoId: vehicle.idVehiculo,
    );

    await _loadAllData(showLoader: false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          actualizado != null
              ? 'Conductor desasignado correctamente'
              : 'No se pudo desasignar el conductor',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _vehicles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE66B6B),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar vehiculos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _loadVehicles(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F4CE8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 620;

        // Mostrar skeleton loading si está cargando
        if (_isLoading) {
          return _buildLoadingSkeletonGrid(isCompact);
        }

        final List<_Vehicle> filtered = _filteredVehicles;
        final double paddingHorizontal = isCompact ? 16 : 24;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _viendoPersona
                    ? 'Vehículos de ${widget.personaNombre ?? 'la persona'}'
                    : 'Vehículos registrados',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Consulta la flota disponible y su estado operativo.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 12,
                ),
              ),
              const SizedBox(height: 14),
              _buildVehicleTopActions(isCompact),
              const SizedBox(height: 12),
              _buildFiltersRow(isCompact),
              const SizedBox(height: 12),
              _buildStatusChips(isCompact),
              const SizedBox(height: 14),
              if (_statusFilter != null || _searchTerm.isNotEmpty)
                _buildActiveFiltersBanner(isCompact),
              if (filtered.isEmpty)
                _buildEmptyFilteredMessage(isCompact)
              else
                _buildVehiclesResponsiveGrid(filtered, isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersRow(bool isCompact) {
    return Row(
      children: [
        Expanded(child: _buildSearchField(isCompact)),
        SizedBox(width: isCompact ? 10 : 10),
        TextButton.icon(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: isCompact ? 6 : 8,
            ),
          ),
          icon: Icon(Icons.clear_all, size: isCompact ? 16 : 16),
          label: Text(
            'Limpiar',
            style: TextStyle(fontSize: isCompact ? 11 : 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isCompact) {
    return TextField(
      onChanged: (value) => setState(() {
        _searchTerm = value.trim();
      }),
      style: TextStyle(color: Colors.white, fontSize: isCompact ? 12 : 13),
      decoration: InputDecoration(
        hintText: 'Buscar por placa, marca o modelo',
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.white54,
          size: isCompact ? 16 : 18,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: EdgeInsets.symmetric(
          vertical: isCompact ? 4 : 6,
          horizontal: isCompact ? 10 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          borderSide: const BorderSide(color: Color(0xFF4F4CE8)),
        ),
      ),
    );
  }

  Widget _buildStatusChips(bool isCompact) {
    final Map<String, int> counts = _statusCounts;
    final List<String> orderedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    if (orderedKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: isCompact ? 8 : 10,
      runSpacing: isCompact ? 8 : 10,
      children: orderedKeys.map((key) {
        final bool selected = _statusFilter == key;
        return GestureDetector(
          onTap: () => _setStatusFilter(key),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 12,
                vertical: isCompact ? 6 : 7,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? _statusColor(key).withValues(alpha: 0.28)
                    : _statusColor(key).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? _statusColor(key)
                      : _statusColor(key).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.circle,
                    color: _statusColor(key),
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _statusLabel(key),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10 : 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    counts[key].toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveFiltersBanner(bool isCompact) {
    final List<String> badges = <String>[];
    if (_statusFilter != null) {
      badges.add('Estado: ${_statusLabel(_statusFilter!)}');
    }
    if (_searchTerm.isNotEmpty) {
      badges.add('Busqueda: $_searchTerm');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            color: Colors.white70,
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: badges
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11 : 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeletonGrid(bool isCompact) {
    final double paddingHorizontal = isCompact ? 16 : 24;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerSkeleton(
            width: 200,
            height: 24,
            borderRadius: 8,
            margin: const EdgeInsets.only(bottom: 8),
          ),
          ShimmerSkeleton(
            width: 350,
            height: 14,
            borderRadius: 6,
            margin: const EdgeInsets.only(bottom: 20),
          ),
          ...List.generate(
            6,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShimmerSkeleton(
                            width: 100,
                            height: 18,
                            borderRadius: 4,
                          ),
                        ),
                        ShimmerSkeleton(width: 80, height: 18, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(width: 150, height: 14, borderRadius: 4),
                    const SizedBox(height: 10),
                    ShimmerSkeleton(width: 180, height: 13, borderRadius: 4),
                    const SizedBox(height: 6),
                    ShimmerSkeleton(width: 160, height: 13, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredMessage(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No hay vehiculos con los filtros actuales',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con otro estado, ajusta la busqueda o limpia los filtros.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isCompact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesResponsiveGrid(List<_Vehicle> vehicles, bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        int crossAxisCount = 1;

        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 900) {
          crossAxisCount = 3;
        } else if (width >= 560) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          itemCount: vehicles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isCompact ? 1.08 : 1.18,
          ),
          itemBuilder: (context, index) {
            return _buildVehicleGridCard(vehicles[index], isCompact);
          },
        );
      },
    );
  }

  Widget _buildVehicleGridCard(_Vehicle vehicle, bool isCompact) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final detailedVehicle = await _getVehicleDetailOnDemand(vehicle);

        if (!mounted) return;

        _showVehicleModal(detailedVehicle, isCompact);
      },
      child: Container(
        padding: EdgeInsets.all(isCompact ? 13 : 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _statusColor(
                      vehicle.estadoVehiculo,
                    ).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: _statusColor(vehicle.estadoVehiculo),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vehicle.placa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 16 : 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildVehicleActionsMenu(vehicle),
              ],
            ),

            const SizedBox(height: 10),

            _buildStatusTag(vehicle.estadoVehiculo, isCompact),

            const SizedBox(height: 10),

            Text(
              '${vehicle.marca} • ${vehicle.modelo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (vehicle.anio != null) ...[
              const SizedBox(height: 4),
              Text(
                'Año ${vehicle.anio}',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
            ],

            const Spacer(),

            if (vehicle.nombrePropietario != null &&
                vehicle.nombrePropietario!.trim().isNotEmpty)
              _buildMiniVehicleLine(
                icon: Icons.person_rounded,
                text: vehicle.nombrePropietario!,
                color: _successColor,
                isCompact: isCompact,
              ),

            if (vehicle.nombreConductor != null &&
                vehicle.nombreConductor!.trim().isNotEmpty)
              _buildMiniVehicleLine(
                icon: Icons.badge_rounded,
                text: vehicle.nombreConductor!,
                color: const Color(0xFF9D84FF),
                isCompact: isCompact,
              ),

            const SizedBox(height: 8),

            Row(
              children: [
                if (vehicle.color != null && vehicle.color!.trim().isNotEmpty)
                  Expanded(
                    child: Text(
                      vehicle.color!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: isCompact ? 10 : 11,
                      ),
                    ),
                  )
                else
                  const Spacer(),

                if (vehicle.documentosVehiculo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${vehicle.documentosVehiculo.length} docs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniVehicleLine({
    required IconData icon,
    required String text,
    required Color color,
    required bool isCompact,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: isCompact ? 14 : 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleModal(_Vehicle vehicle, bool isCompact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isCompact ? 400 : 700,
              maxHeight: 800,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información del Vehículo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.placa,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.marca} • ${vehicle.modelo}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Detalles Principales del Vehículo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Color(0xFF4F4CE8),
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Detalles Principales',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Placa', vehicle.placa),
                        _buildInfoRow('Marca', vehicle.marca),
                        _buildInfoRow('Modelo', vehicle.modelo),
                        if (vehicle.anio != null)
                          _buildInfoRow('Año', vehicle.anio.toString()),
                        if (vehicle.color != null)
                          _buildInfoRow('Color', vehicle.color!),
                        _buildInfoRow(
                          'Estado',
                          _statusLabel(vehicle.estadoVehiculo),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información Operativa
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.speed,
                              color: Color(0xFF4F4CE8),
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Información Operativa',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Kilometraje',
                          '${vehicle.kilometrajeActual} km',
                        ),
                        if (vehicle.vin != null)
                          _buildInfoRow('VIN', vehicle.vin!),
                        if (vehicle.fechaCreacion != null)
                          _buildInfoRow(
                            'Registrado',
                            _dateFormat.format(vehicle.fechaCreacion!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información del Propietario
                  if (vehicle.nombrePropietario != null &&
                      vehicle.nombrePropietario!.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(context);

                        if (widget.onVerPropietario != null &&
                            vehicle.idPropietario > 0) {
                          widget.onVerPropietario!(
                            propietarioId: vehicle.idPropietario,
                          );
                          return;
                        }

                        _showPersonaInfoModal(
                          tipo: 'Información del propietario',
                          nombre:
                              vehicle.nombrePropietario ?? 'Sin propietario',
                          telefono: vehicle.telefonoPropietario,
                          correo: vehicle.emailPropietario,
                          documento: vehicle.documentoPropietario,
                          tipoDocumento: vehicle.tipoDocumentoPropietario,
                          apellido: vehicle.apellidoPropietario,
                          direccion: vehicle.direccionPropietario,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Propietario',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Nombre', vehicle.nombrePropietario!),
                            if (vehicle.documentoPropietario != null &&
                                vehicle.documentoPropietario!.isNotEmpty)
                              _buildInfoRow(
                                'Documento',
                                vehicle.documentoPropietario!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Información del Conductor
                  if (vehicle.nombreConductor != null &&
                      vehicle.nombreConductor!.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(context);

                        if (widget.onVerConductor != null &&
                            vehicle.idConductor != null) {
                          widget.onVerConductor!(
                            conductorId: vehicle.idConductor!,
                          );
                          return;
                        }

                        _showPersonaInfoModal(
                          tipo: 'Información del conductor',
                          nombre: vehicle.nombreConductor ?? 'Sin conductor',
                          telefono: vehicle.telefonoConductor,
                          correo: vehicle.emailConductor,
                          documento: vehicle.documentoConductor,
                          tipoDocumento: vehicle.tipoDocumentoConductor,
                          apellido: vehicle.apellidoConductor,
                          direccion: vehicle.direccionConductor,
                          licencia: vehicle.licenciaConductor,
                          categoria: vehicle.categoriaConductor,
                          vencimientoLicencia: vehicle.fechaVencimientoLicencia,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Conductor Asignado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Nombre', vehicle.nombreConductor!),
                            if (vehicle.documentoConductor != null &&
                                vehicle.documentoConductor!.isNotEmpty)
                              _buildInfoRow(
                                'Documento',
                                vehicle.documentoConductor!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _buildVehicleActionButtons(vehicle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPersonaInfoModal({
    required String tipo,
    required String nombre,
    String? telefono,
    String? correo,
    String? documento,
    String? tipoDocumento,
    String? apellido,
    String? direccion,
    String? licencia,
    String? categoria,
    DateTime? vencimientoLicencia,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalHeader(
                  title: tipo,
                  subtitle: nombre,
                  icon: tipo.toLowerCase().contains('propietario')
                      ? Icons.person_rounded
                      : Icons.badge_rounded,
                ),
                const SizedBox(height: 18),

                _buildPersonInfoRow('Nombre', nombre),
                _buildPersonInfoRow('Apellido', apellido),
                _buildPersonInfoRow('Tipo documento', tipoDocumento),
                _buildPersonInfoRow('Dirección', direccion),
                _buildPersonInfoRow('Teléfono', telefono),
                _buildPersonInfoRow('Correo', correo),
                _buildPersonInfoRow('Documento', documento),

                if (licencia != null && licencia.trim().isNotEmpty)
                  _buildPersonInfoRow('Licencia', licencia),

                if (categoria != null && categoria.trim().isNotEmpty)
                  _buildPersonInfoRow('Categoría', categoria),

                if (vencimientoLicencia != null)
                  _buildPersonInfoRow(
                    'Vencimiento licencia',
                    _dateFormat.format(vencimientoLicencia),
                  ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonInfoRow(String label, String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleActionButtons(_Vehicle vehicle) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);

                  if (widget.onVerDocumentosVehiculo != null) {
                    widget.onVerDocumentosVehiculo!.call(
                      vehiculoId: vehicle.idVehiculo,
                      placa: vehicle.placa,
                    );
                  }
                },
                icon: const Icon(Icons.description_rounded),
                label: const Text('Ver documentos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);

                  if (widget.onVerMantenimientosVehiculo != null) {
                    widget.onVerMantenimientosVehiculo!.call(
                      vehiculoId: vehicle.idVehiculo,
                      placa: vehicle.placa,
                    );
                  }
                },
                icon: const Icon(Icons.build_rounded),
                label: const Text('Ver mantenimientos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
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

  Widget _buildVehicleActionsMenu(_Vehicle vehicle) {
    if (!_canEditVehicleInfo && !_canManageDriverAssignment) {
      return const SizedBox.shrink();
    }

    final bool hasDriver =
        vehicle.nombreConductor != null &&
        vehicle.nombreConductor!.trim().isNotEmpty;

    return PopupMenuButton<String>(
      color: const Color(0xFF151B47),
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Colors.white70,
        size: 20,
      ),
      onSelected: (value) {
        if (value == 'editar') {
          _showEditVehicleModal(vehicle);
        } else if (value == 'asignar') {
          _showAssignDriverModal(vehicle);
        } else if (value == 'desasignar') {
          _desasignarConductor(vehicle);
        }
      },
      itemBuilder: (context) => [
        if (_canEditVehicleInfo)
          const PopupMenuItem(
            value: 'editar',
            child: Text(
              'Editar vehículo',
              style: TextStyle(color: Colors.white),
            ),
          ),

        if (_canManageDriverAssignment && !hasDriver)
          const PopupMenuItem(
            value: 'asignar',
            child: Text(
              'Asignar conductor',
              style: TextStyle(color: Colors.white),
            ),
          ),

        if (_canManageDriverAssignment && hasDriver)
          const PopupMenuItem(
            value: 'desasignar',
            child: Text(
              'Desasignar conductor',
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusTag(String status, bool isCompact) {
    final Color color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
