import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontendproyecto/utils/api_config.dart';
import 'package:frontendproyecto/widgets/shimmer_skeleton.dart';
import 'document_modal.dart';

/// Visualiza los registros de la tabla vehiculos con filtros basados en estado y busqueda.
class VehiculosWidget extends StatefulWidget {
  final String role;
  final String? ownerId;
  final String? jsonPath;
  final bool showOwnerColumn;

  const VehiculosWidget({
    super.key,
    required this.role,
    this.ownerId,
    this.jsonPath,
    this.showOwnerColumn = false,
  });

  @override
  State<VehiculosWidget> createState() => _VehiculosWidgetState();
}

class _Vehicle {
  final int idVehiculo;
  final int idPropietario;
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
  // Información del Conductor
  final String? telefonoConductor;
  final String? emailConductor;
  final String? licenciaConductor;
  final String? categoriaConductor;
  final DateTime? fechaVencimientoLicencia;
  // Documentos
  final List<Map<String, dynamic>> documentosVehiculo;
  final int cantidadDocumentosVigentes;

  const _Vehicle({
    required this.idVehiculo,
    required this.idPropietario,
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
    this.telefonoConductor,
    this.emailConductor,
    this.licenciaConductor,
    this.categoriaConductor,
    this.fechaVencimientoLicencia,
    this.documentosVehiculo = const [],
    this.cantidadDocumentosVigentes = 0,
  });

  String get statusKey => estadoVehiculo.toUpperCase();
}

class _VehiculosWidgetState extends State<VehiculosWidget> {
  static const Color _accentColor = Color(0xFF4F4CE8);
  static const Color _cardColor = Color(0xFF1B1F6B);
  static const Color _successColor = Color(0xFF16C79A);
  static const Color _warningColor = Color(0xFFEFB549);
  static const Color _dangerColor = Color(0xFFE66B6B);

  bool _isLoading = true;
  List<_Vehicle> _vehicles = const [];
  Map<String, List<Map<String, dynamic>>> _vehicleDocumentsByPlate = {};
  Map<int, Map<String, dynamic>> _propietariosMap = {};
  Map<int, Map<String, dynamic>> _conductoresMap = {};
  String? _statusFilter;
  String _searchTerm = '';
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String _baseUrl = ApiConfig.fallbackBaseUrl();
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initBaseUrl();
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadPropietariosFromApi(),
      _loadConductoresFromApi(),
      _loadDocumentsFromApi(),
    ]);
    await _loadVehicles();
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
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _propietariosMap.clear();
        
        for (final prop in data.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse(prop['id']?.toString() ?? prop['idPropietario']?.toString() ?? '');
          final nombre = prop['nombre']?.toString() ?? 'Desconocido';
          if (id != null) {
            _propietariosMap[id] = {...prop, 'nombre': nombre};
          }
        }
        debugPrint('✅ Propietarios cargados: ${_propietariosMap.length} registros');
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
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _conductoresMap.clear();
        
        for (final cond in data.whereType<Map<String, dynamic>>()) {
          final id = int.tryParse(cond['id']?.toString() ?? cond['idConductor']?.toString() ?? '');
          final nombre = cond['nombre']?.toString() ?? 'Desconocido';
          if (id != null) {
            _conductoresMap[id] = {...cond, 'nombre': nombre};
          }
        }
        debugPrint('✅ Conductores cargados: ${_conductoresMap.length} registros');
      }
    } catch (e) {
      debugPrint('❌ Error cargando conductores: $e');
    }
  }

  Future<void> _loadVehicles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Obtener token de SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      // Construir URL según el rol y el ownerId
      String endpoint = '/api/vehiculos';
      
      // Si es propietario y hay ownerId, usar endpoint específico del propietario
      if (widget.role.toLowerCase() == 'propietario' && widget.ownerId != null && widget.ownerId!.isNotEmpty) {
        endpoint = '/api/propietarios/${widget.ownerId}/vehiculos';
        debugPrint('📍 Modo Propietario: Cargando vehículos para propietario ${widget.ownerId}');
      }
      // Si es conductor y hay ownerId, usar endpoint específico del conductor
      else if (widget.role.toLowerCase() == 'conductor' && widget.ownerId != null && widget.ownerId!.isNotEmpty) {
        endpoint = '/api/conductores/${widget.ownerId}/vehiculos';
        debugPrint('📍 Modo Conductor: Cargando vehículos para conductor ${widget.ownerId}');
      }

      final uri = ApiConfig.resolve(_baseUrl, endpoint);
      debugPrint('🔗 Cargando vehículos desde: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Respuesta: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<_Vehicle> vehicles = _parseVehiclesFromApi(data);
        
        // Cargar detalles completos de cada vehículo en paralelo
        final List<_Vehicle> detailedVehicles = await _loadVehiclesDetails(vehicles, token);
        final List<_Vehicle> enrichedVehicles = _enrichVehiclesWithNames(detailedVehicles);
        
        // Enriquecer vehículos con documentos cargados desde la API
        final List<_Vehicle> vehiclesWithDocuments = _enrichVehiclesWithDocuments(enrichedVehicles);

        vehiclesWithDocuments.sort((a, b) => a.placa.compareTo(b.placa));

        setState(() {
          _vehicles = vehiclesWithDocuments;
          _isLoading = false;
        });

        debugPrint('✅ ${vehiclesWithDocuments.length} vehículos cargados con detalles completos desde API');
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permisos para ver los vehículos.');
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ No se encontraron vehículos en el endpoint: $endpoint');
        // Para 404, intentar cargar desde el endpoint general como fallback
        if (widget.role.toLowerCase() != 'empresa') {
          debugPrint('🔄 Intentando cargar desde endpoint general como fallback...');
          await _loadVehiclesFromGeneral(token);
          return;
        }
        throw Exception('No se encontraron vehículos para este usuario.');
      } else {
        throw Exception('Error ${response.statusCode}: No se pudieron cargar los vehículos');
      }
    } catch (e) {
      debugPrint('❌ Error cargando vehículos: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _vehicles = _fallbackVehicles();
      });
    }
  }

  // Método para cargar desde endpoint general como fallback
  Future<void> _loadVehiclesFromGeneral(String token) async {
    try {
      final uri = ApiConfig.resolve(_baseUrl, '/api/vehiculos');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<_Vehicle> vehicles = _parseVehiclesFromApi(data);
        
        final List<_Vehicle> detailedVehicles = await _loadVehiclesDetails(vehicles, token);
        final List<_Vehicle> enrichedVehicles = _enrichVehiclesWithNames(detailedVehicles);
        final List<_Vehicle> vehiclesWithDocuments = _enrichVehiclesWithDocuments(enrichedVehicles);

        // Si tenemos ownerId, filtrar por ese propietario
        List<_Vehicle> filtered = vehiclesWithDocuments;
        if (widget.ownerId != null && widget.ownerId!.isNotEmpty) {
          final int? ownerId = int.tryParse(widget.ownerId!);
          if (ownerId != null) {
            filtered = vehiclesWithDocuments.where((v) => v.idPropietario == ownerId).toList();
            debugPrint('✅ Filtrados ${filtered.length} vehículos para propietario $ownerId');
          }
        }

        filtered.sort((a, b) => a.placa.compareTo(b.placa));

        setState(() {
          _vehicles = filtered;
          _isLoading = false;
        });

        debugPrint('✅ ${filtered.length} vehículos cargados desde fallback');
      }
    } catch (e) {
      debugPrint('❌ Error en fallback: $e');
    }
  }

  Future<List<_Vehicle>> _loadVehiclesDetails(List<_Vehicle> vehicles, String token) async {
    final List<Future<_Vehicle>> futures = [];
    
    for (final vehicle in vehicles) {
      futures.add(_loadVehicleDetail(vehicle, token));
    }
    
    final results = await Future.wait(futures, eagerError: false);
    return results.whereType<_Vehicle>().toList();
  }

  Future<_Vehicle> _loadVehicleDetail(_Vehicle vehicle, String token) async {
    try {
      final uri = ApiConfig.resolve(_baseUrl, '/api/vehiculos/${vehicle.idVehiculo}/detalle');
      debugPrint('📡 Cargando detalle de vehículo ${vehicle.idVehiculo} desde: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Respuesta recibida para vehículo ${vehicle.idVehiculo}');
        debugPrint('   - Claves disponibles: ${data.keys.toList()}');
        debugPrint('   - nombrePropietario: ${data['nombrePropietario']}');
        debugPrint('   - nombreConductor: ${data['nombreConductor']}');
        debugPrint('   - propietario (está?): ${data.containsKey('propietario')}');
        debugPrint('   - conductor (está?): ${data.containsKey('conductor')}');
        
        return _enrichVehicleFromDetalle(vehicle, data);
      } else {
        debugPrint('⚠️ Error ${response.statusCode} cargando detalle ${vehicle.idVehiculo}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando detalle de vehículo ${vehicle.idVehiculo}: $e');
    }
    debugPrint('↩️  Retornando vehículo sin enriquecimiento: ${vehicle.placa}');
    return vehicle;
  }

  _Vehicle _enrichVehicleFromDetalle(_Vehicle vehicle, Map<String, dynamic> data) {
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
        nombreProp = nombreProp ?? '${usuario['nombre']?.toString() ?? ''} ${usuario['apellido']?.toString() ?? ''}'.trim();
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
      if ((docProp == null || docProp.isEmpty) && propietario['usuario'] is Map<String, dynamic>) {
        final usuario = propietario['usuario'] as Map<String, dynamic>;
        docProp = usuario['numeroDocumento']?.toString();
      }
    }
    
    // Intentar extraer desde campos top-level (alternativa)
    if ((nombreProp == null || nombreProp.isEmpty)) {
      nombreProp = data['nombrePropietario']?.toString();
      if (nombreProp == null || nombreProp.isEmpty) {
        nombreProp = '${data['apellidoPropietario']?.toString() ?? ''} ${data['nombrePropietario']?.toString() ?? ''}'.trim();
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
        nombreCond = nombreCond ?? '${usuario['nombre']?.toString() ?? ''} ${usuario['apellido']?.toString() ?? ''}'.trim();
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
        nombreCond = '${data['apellidoConductor']?.toString() ?? ''} ${data['nombreConductor']?.toString() ?? ''}'.trim();
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

    debugPrint('🔄 Vehículo ${vehicle.placa}: Prop=$nombreProp (Doc:$docProp), Tel:$telProp, Cond=$nombreCond');

    // Extraer documentos del detalle si vienen en la respuesta
    List<Map<String, dynamic>> documentsFromDetail = [];
    if (data['documentos'] is List) {
      documentsFromDetail = (data['documentos'] as List).whereType<Map<String, dynamic>>().toList();
      debugPrint('📄 Documentos encontrados en detalle: ${documentsFromDetail.length}');
    }

    return _Vehicle(
      idVehiculo: vehicle.idVehiculo,
      idPropietario: vehicle.idPropietario,
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
      documentosVehiculo: documentsFromDetail.isNotEmpty ? documentsFromDetail : vehicle.documentosVehiculo,
      cantidadDocumentosVigentes: vehicle.cantidadDocumentosVigentes,
    );
  }

  List<_Vehicle> _parseVehiclesFromApi(List<dynamic> data) {
    return data.map((dynamic item) {
      if (item is! Map<String, dynamic>) return null;
      
      final Map<String, dynamic> map = item;
      final int? id = int.tryParse(map['id']?.toString() ?? map['idVehiculo']?.toString() ?? '');
      final int? ownerId = int.tryParse(map['idPropietario']?.toString() ?? '');
      
      if (id == null) return null;

      final int kilometraje = int.tryParse(map['kilometrajeActual']?.toString() ?? '') ?? 0;
      final int? anio = int.tryParse(map['anio']?.toString() ?? '');
      final DateTime? fecha = DateTime.tryParse(map['fechaCreacion']?.toString() ?? '');

      return _Vehicle(
        idVehiculo: id,
        idPropietario: ownerId ?? 0,
        placa: map['placa']?.toString() ?? 'SIN PLACA',
        vin: map['vin']?.toString(),
        marca: map['marca']?.toString() ?? 'Marca desconocida',
        modelo: map['modelo']?.toString() ?? 'Modelo desconocido',
        anio: anio,
        color: map['color']?.toString(),
        kilometrajeActual: kilometraje,
        estadoVehiculo: map['estadoVehiculo']?.toString() ?? 'ACTIVO',
        fechaCreacion: fecha,
        nombrePropietario: map['propietario']?['nombre']?.toString() ?? map['nombrePropietario']?.toString(),
        nombreConductor: map['conductor']?['nombre']?.toString() ?? map['nombreConductor']?.toString(),
      );
    }).whereType<_Vehicle>().toList();
  }

  List<_Vehicle> _enrichVehiclesWithNames(List<_Vehicle> vehicles) {
    return vehicles.map((vehicle) {
      String? nombreProp = vehicle.nombrePropietario;
      String? nombreCond = vehicle.nombreConductor;

      // Si no tiene nombre de propietario, intenta obtenerlo del mapa
      if ((nombreProp == null || nombreProp.isEmpty) && vehicle.idPropietario > 0) {
        nombreProp = _propietariosMap[vehicle.idPropietario]?['nombre']?.toString();
      }

      return _Vehicle(
        idVehiculo: vehicle.idVehiculo,
        idPropietario: vehicle.idPropietario,
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
        telefonoPropietario: vehicle.telefonoPropietario,
        emailPropietario: vehicle.emailPropietario,
        documentoPropietario: vehicle.documentoPropietario,
        telefonoConductor: vehicle.telefonoConductor,
        emailConductor: vehicle.emailConductor,
        licenciaConductor: vehicle.licenciaConductor,
        categoriaConductor: vehicle.categoriaConductor,
        fechaVencimientoLicencia: vehicle.fechaVencimientoLicencia,
        documentosVehiculo: vehicle.documentosVehiculo,
        cantidadDocumentosVigentes: vehicle.cantidadDocumentosVigentes,
      );
    }).toList();
  }

  List<_Vehicle> _enrichVehiclesWithDocuments(List<_Vehicle> vehicles) {
    return vehicles.map((vehicle) {
      // Obtener documentos para este vehículo desde el mapa cargado
      final docs = _vehicleDocumentsByPlate[vehicle.placa] ?? [];
      
      // Si el vehículo ya tiene documentos del detalle, no sobrescribir
      final docsToUse = vehicle.documentosVehiculo.isNotEmpty ? vehicle.documentosVehiculo : docs;
      
      if (docsToUse.isNotEmpty) {
        debugPrint('📄 Vehículo ${vehicle.placa}: ${docsToUse.length} documentos asignados');
      }
      
      return _Vehicle(
        idVehiculo: vehicle.idVehiculo,
        idPropietario: vehicle.idPropietario,
        placa: vehicle.placa,
        vin: vehicle.vin,
        marca: vehicle.marca,
        modelo: vehicle.modelo,
        anio: vehicle.anio,
        color: vehicle.color,
        kilometrajeActual: vehicle.kilometrajeActual,
        estadoVehiculo: vehicle.estadoVehiculo,
        fechaCreacion: vehicle.fechaCreacion,
        nombrePropietario: vehicle.nombrePropietario,
        nombreConductor: vehicle.nombreConductor,
        telefonoPropietario: vehicle.telefonoPropietario,
        emailPropietario: vehicle.emailPropietario,
        documentoPropietario: vehicle.documentoPropietario,
        telefonoConductor: vehicle.telefonoConductor,
        emailConductor: vehicle.emailConductor,
        licenciaConductor: vehicle.licenciaConductor,
        categoriaConductor: vehicle.categoriaConductor,
        fechaVencimientoLicencia: vehicle.fechaVencimientoLicencia,
        documentosVehiculo: docsToUse,
        cantidadDocumentosVigentes: vehicle.cantidadDocumentosVigentes,
      );
    }).toList();
  }

  Future<void> _loadDocumentsFromApi() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      if (token == null) return;

      final uri = ApiConfig.resolve(_baseUrl, '/api/documentos/tabla');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _vehicleDocumentsByPlate.clear();
        
        for (final doc in data.whereType<Map<String, dynamic>>()) {
          // Filtrar solo documentos de vehículos (id_usuario = null)
          final idUsuario = doc['idUsuario'];
          if (idUsuario == null) {
            final placa = doc['vehiculoPlaca']?.toString() ?? doc['placa']?.toString() ?? '';
            if (placa.isNotEmpty) {
              if (!_vehicleDocumentsByPlate.containsKey(placa)) {
                _vehicleDocumentsByPlate[placa] = [];
              }
              _vehicleDocumentsByPlate[placa]!.add(doc);
              debugPrint('📄 Documento de vehículo encontrado: $placa - ${doc['nombre']?.toString() ?? 'Sin nombre'}');
            }
          }
        }
        debugPrint('✅ Documentos de vehículos cargados: ${_vehicleDocumentsByPlate.values.fold<int>(0, (sum, list) => sum + list.length)} registros');
      } else {
        debugPrint('⚠️ Error ${response.statusCode} cargando documentos: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando documentos: $e');
    }
  }

  List<_Vehicle> _fallbackVehicles() {
    final DateTime now = DateTime.now();
    return [
      _Vehicle(
        idVehiculo: 1,
        idPropietario: 12,
        placa: 'ABC123',
        vin: '1HGCM82633A004352',
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2020,
        color: 'Rojo',
        kilometrajeActual: 25000,
        estadoVehiculo: 'ACTIVO',
        fechaCreacion: now.subtract(const Duration(days: 180)),
        nombrePropietario: 'Carlos González',
        nombreConductor: 'Juan Pérez',
        telefonoPropietario: '3001234567',
        emailPropietario: 'carlos@email.com',
        documentoPropietario: '1234567890',
        telefonoConductor: '3007654321',
        emailConductor: 'juan@email.com',
        licenciaConductor: '12AB34CD',
        categoriaConductor: 'C',
        fechaVencimientoLicencia: now.add(const Duration(days: 180)),
      ),
      _Vehicle(
        idVehiculo: 2,
        idPropietario: 12,
        placa: 'XYZ789',
        vin: 'JHMCM56557C404453',
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2021,
        color: 'Gris',
        kilometrajeActual: 90000,
        estadoVehiculo: 'ACTIVO',
        fechaCreacion: now.subtract(const Duration(days: 420)),
        nombrePropietario: 'Carlos González',
        telefonoPropietario: '3001234567',
        emailPropietario: 'carlos@email.com',
      ),
    ];
  }

  List<_Vehicle> get _filteredVehicles {
    Iterable<_Vehicle> filtered = _vehicles;

    if (widget.ownerId != null && widget.ownerId!.isNotEmpty) {
      final int? owner = int.tryParse(widget.ownerId!);
      if (owner != null) {
        final List<_Vehicle> ownerMatches = filtered.where((vehicle) => vehicle.idPropietario == owner).toList();
        if (ownerMatches.isNotEmpty) {
          filtered = ownerMatches;
        }
      }
    }

    if (_statusFilter != null) {
      final String normalized = _statusFilter!;
      filtered = filtered.where((vehicle) => vehicle.statusKey == normalized);
    }

    if (_searchTerm.isNotEmpty) {
      final String lower = _searchTerm.toLowerCase();
      filtered = filtered.where((vehicle) {
        return vehicle.placa.toLowerCase().contains(lower) ||
            (vehicle.marca.toLowerCase().contains(lower)) ||
            (vehicle.modelo.toLowerCase().contains(lower));
      });
    }

    final List<_Vehicle> result = filtered.toList();
    result.sort((a, b) => a.placa.compareTo(b.placa));
    return result;
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

  Map<String, int> get _statusCounts {
    final Map<String, int> counts = <String, int>{};
    for (final _Vehicle vehicle in _vehicles) {
      counts.update(vehicle.statusKey, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Color _statusColor(String status) {
    final String normalized = status.toUpperCase();
    if (normalized == 'ACTIVO') {
      return _successColor;
    }
    if (normalized == 'MANTENIMIENTO' || normalized == 'MANTENIMIENTO PROGRAMADO') {
      return _warningColor;
    }
    if (normalized == 'INACTIVO' || normalized == 'FUERA DE SERVICIO') {
      return _dangerColor;
    }
    return _accentColor;
  }

  DateTime? _parseDocDate(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  void _openVehicleDocument(Map<String, dynamic> doc, String plate) {
    final String name = doc['name']?.toString() ?? 'Documento';
    final DateTime? expiry = _parseDocDate(doc['expiryDate']?.toString());
    final DateTime? payment = _parseDocDate(doc['paymentDate']?.toString());

    if (expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay fecha de vencimiento disponible para este documento.'),
          backgroundColor: Color(0xFFE66B6B),
        ),
      );
      return;
    }

    DocumentModal.show(
      context: context,
      documentName: '$name • $plate',
      creationDate: payment,
      expiryDate: expiry,
    );
  }

  Widget _buildVehicleDocumentsList(String plate, bool isCompact) {
    final List<Map<String, dynamic>> docs = _vehicleDocumentsByPlate[plate] ?? [];

    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No hay documentos para $plate', style: const TextStyle(color: Colors.white70)),
      );
    }

    return Column(
      children: docs.map((d) {
        // Extraer información del documento
        final String name = d['nombre']?.toString() ?? d['name']?.toString() ?? 'Documento';
        final String estado = d['estado']?.toString() ?? d['status']?.toString() ?? 'DESCONOCIDO';
        final String numero = d['numero']?.toString() ?? d['numeroDocumento']?.toString() ?? '';
        final DateTime? expiry = _parseDocDate(d['fechaVencimiento']?.toString() ?? d['expiryDate']?.toString());
        final DateTime? payment = _parseDocDate(d['fechaPago']?.toString() ?? d['paymentDate']?.toString());
        final DateTime? createdAt = _parseDocDate(d['fechaCreacion']?.toString() ?? d['createdAt']?.toString());
        final String descripcion = d['descripcion']?.toString() ?? '';
        
        // Determinar el color del estado
        Color estadoColor = Colors.white70;
        if (estado.toUpperCase().contains('VIGENTE')) {
          estadoColor = Color(0xFF16C79A); // Verde
        } else if (estado.toUpperCase().contains('VENCIDO')) {
          estadoColor = Color(0xFFEF476F); // Rojo
        } else if (estado.toUpperCase().contains('PROXIMO')) {
          estadoColor = Color(0xFFEFB549); // Amarillo
        }
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openVehicleDocument(d, plate),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y estado en la misma fila
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: estadoColor, width: 0.5),
                        ),
                        child: Text(
                          estado,
                          style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Información detallada
                  if (numero.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.numbers, color: Colors.white54, size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Número: $numero',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  // Fechas importantes
                  if (expiry != null || payment != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white54, size: 13),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Venc: ${_dateFormat.format(expiry ?? DateTime.now())}',
                                  style: TextStyle(
                                    color: expiry != null && expiry.isBefore(DateTime.now().add(Duration(days: 30)))
                                        ? Color(0xFFEFB549)
                                        : Colors.white70,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (payment != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF16C79A), size: 13),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_dateFormat.format(payment)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  // Descripción si existe
                  if (descripcion.isNotEmpty) ...[
                    Text(
                      descripcion,
                      style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  // Fecha de creación
                  if (createdAt != null) ...[
                    Text(
                      'Cargado: ${_dateFormat.format(createdAt)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  // Link para ver detalle
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Ver detalle y descargar', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Colors.white54, size: 13),
                      ],
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

  String _statusLabel(String status) {
    if (status.isEmpty) {
      return 'Desconocido';
    }
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
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
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE66B6B), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar vehiculos',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadVehicles,
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
          padding: EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehiculos registrados',
                style: TextStyle(color: Colors.white, fontSize: isCompact ? 18 : 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Consulta la flota disponible y su estado operativo.',
                style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 12),
              ),
              const SizedBox(height: 14),
              _buildFiltersRow(isCompact),
              const SizedBox(height: 12),
              _buildStatusChips(isCompact),
              const SizedBox(height: 14),
              if (_statusFilter != null || _searchTerm.isNotEmpty)
                _buildActiveFiltersBanner(isCompact),
              if (filtered.isEmpty)
                _buildEmptyFilteredMessage(isCompact)
              else
                Column(
                  children: filtered.map((vehicle) => _buildVehicleListCard(vehicle, isCompact)).toList(),
                ),
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
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 6 : 8),
          ),
          icon: Icon(Icons.clear_all, size: isCompact ? 16 : 16),
          label: Text('Limpiar', style: TextStyle(fontSize: isCompact ? 11 : 11)),
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
        prefixIcon: Icon(Icons.search, color: Colors.white54, size: isCompact ? 16 : 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6, horizontal: isCompact ? 10 : 14),
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
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 6 : 7),
              decoration: BoxDecoration(
                color: selected
                  ? _statusColor(key).withValues(alpha: 0.28)
                  : _statusColor(key).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? _statusColor(key) : _statusColor(key).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.check_circle : Icons.circle, color: _statusColor(key), size: 12),
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
                    style: TextStyle(color: Colors.white, fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w700),
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
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, color: Colors.white70, size: isCompact ? 18 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: badges
                  .map((label) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(label, style: TextStyle(color: Colors.white, fontSize: isCompact ? 11 : 12)),
                      ))
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
      padding: EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerSkeleton(width: 200, height: 24, borderRadius: 8, margin: const EdgeInsets.only(bottom: 8)),
          ShimmerSkeleton(width: 350, height: 14, borderRadius: 6, margin: const EdgeInsets.only(bottom: 20)),
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
                          child: ShimmerSkeleton(width: 100, height: 18, borderRadius: 4),
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
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No hay vehiculos con los filtros actuales', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Prueba con otro estado, ajusta la busqueda o limpia los filtros.',
            style: TextStyle(color: Colors.white70, fontSize: isCompact ? 12 : 13),
          ),
        ],
      ),
    );
  }

  void _showDocumentsModal(_Vehicle vehicle, bool isCompact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxWidth: isCompact ? 400 : 600, maxHeight: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Documentos del Vehículo',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.placa,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVehicleDocumentsList(vehicle.placa, isCompact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVehicleModal(_Vehicle vehicle, bool isCompact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF151B47),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxWidth: isCompact ? 400 : 700, maxHeight: 800),
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
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.placa,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.marca} • ${vehicle.modelo}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: Color(0xFF4F4CE8), size: 18),
                            SizedBox(width: 10),
                            Text('Detalles Principales', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Placa', vehicle.placa),
                        _buildInfoRow('Marca', vehicle.marca),
                        _buildInfoRow('Modelo', vehicle.modelo),
                        if (vehicle.anio != null) _buildInfoRow('Año', vehicle.anio.toString()),
                        if (vehicle.color != null) _buildInfoRow('Color', vehicle.color!),
                        _buildInfoRow('Estado', _statusLabel(vehicle.estadoVehiculo)),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.speed, color: Color(0xFF4F4CE8), size: 18),
                            SizedBox(width: 10),
                            Text('Información Operativa', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Kilometraje', '${vehicle.kilometrajeActual} km'),
                        if (vehicle.vin != null) _buildInfoRow('VIN', vehicle.vin!),
                        if (vehicle.fechaCreacion != null) _buildInfoRow('Registrado', _dateFormat.format(vehicle.fechaCreacion!)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información del Propietario
                  if (vehicle.nombrePropietario != null && vehicle.nombrePropietario!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person, color: Colors.green, size: 18),
                              SizedBox(width: 10),
                              Text('Propietario', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Nombre', vehicle.nombrePropietario!),
                          if (vehicle.documentoPropietario != null && vehicle.documentoPropietario!.isNotEmpty)
                            _buildInfoRow('Documento', vehicle.documentoPropietario!),
                          if (vehicle.telefonoPropietario != null && vehicle.telefonoPropietario!.isNotEmpty)
                            _buildInfoRow('Teléfono', vehicle.telefonoPropietario!),
                          if (vehicle.emailPropietario != null && vehicle.emailPropietario!.isNotEmpty)
                            _buildInfoRow('Email', vehicle.emailPropietario!),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Información del Conductor
                  if (vehicle.nombreConductor != null && vehicle.nombreConductor!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_car, color: Colors.blue, size: 18),
                              SizedBox(width: 10),
                              Text('Conductor Asignado', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Nombre', vehicle.nombreConductor!),
                          if (vehicle.telefonoConductor != null && vehicle.telefonoConductor!.isNotEmpty)
                            _buildInfoRow('Teléfono', vehicle.telefonoConductor!),
                          if (vehicle.emailConductor != null && vehicle.emailConductor!.isNotEmpty)
                            _buildInfoRow('Email', vehicle.emailConductor!),
                          if (vehicle.licenciaConductor != null && vehicle.licenciaConductor!.isNotEmpty)
                            _buildInfoRow('Licencia', vehicle.licenciaConductor!),
                          if (vehicle.categoriaConductor != null && vehicle.categoriaConductor!.isNotEmpty)
                            _buildInfoRow('Categoría Licencia', vehicle.categoriaConductor!),
                          if (vehicle.fechaVencimientoLicencia != null)
                            _buildInfoRow(
                              'Vencimiento Licencia',
                              _dateFormat.format(vehicle.fechaVencimientoLicencia!),
                            ),
                        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVehicleListCard(_Vehicle vehicle, bool isCompact) {
    return InkWell(
      onTap: () => _showVehicleModal(vehicle, isCompact),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placa y Estado en la misma fila
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.placa,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusTag(vehicle.estadoVehiculo, isCompact),
              ],
            ),
            const SizedBox(height: 8),
            
            // Marca y Modelo
            Text(
              '${vehicle.marca} • ${vehicle.modelo}${vehicle.anio != null ? ' • ${vehicle.anio}' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 10),
            
            // Propietario
            if (vehicle.nombrePropietario != null && vehicle.nombrePropietario!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.person, color: _successColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Propietario: ${vehicle.nombrePropietario}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            
            // Conductor
            if (vehicle.nombreConductor != null && vehicle.nombreConductor!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.directions_car, color: Color(0xFF9D84FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conductor: ${vehicle.nombreConductor}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            
            // Color y Documentos
            if ((vehicle.color != null && vehicle.color!.isNotEmpty) || (vehicle.documentosVehiculo?.isNotEmpty ?? false)) ...[
              Row(
                children: [
                  if (vehicle.color != null && vehicle.color!.isNotEmpty) ...[
                    Icon(Icons.color_lens, color: _warningColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Color: ${vehicle.color}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (vehicle.documentosVehiculo?.isNotEmpty ?? false) ...[
                    Icon(Icons.description, color: _warningColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${vehicle.documentosVehiculo?.length ?? 0} docs',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status, bool isCompact) {
    final Color color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: Colors.white, fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
