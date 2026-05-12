import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './api_link.dart';
import './document_service.dart';

class ApiService {
  // URL base del servidor - siempre usa Onrender
  static String get _baseUrl => getApiLink();

  /// Obtiene el token desde SharedPreferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Construye headers con autenticación
  static Future<Map<String, String>> _buildHeaders({String? token}) async {
    final authToken = token ?? await _getToken();
    return {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  // ==================== EMPRESA ====================

  /// Obtiene datos de la empresa actual del usuario autenticado
  /// GET /api/empresas/{idEmpresa}/detalle
  static Future<Map<String, dynamic>?> getEmpresaActual() async {
    try {
      final headers = await _buildHeaders();

      // Primero obtenemos el empresaId del token o de preferencias
      final prefs = await SharedPreferences.getInstance();
      final empresaId = prefs.getString('empresa_id');

      if (empresaId == null) {
        debugPrint('❌ No hay empresa_id en preferencias');
        return null;
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/empresas/$empresaId/detalle'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Empresa obtenida: ${decoded['nombreEmpresa']}');
        return decoded is Map<String, dynamic> ? decoded : null;
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener empresa');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener empresa: $e');
    }
    return null;
  }

  // ==================== VEHÍCULOS ====================

  /// Obtiene la flota de vehículos de la empresa actual
  /// GET /api/vehiculos
  static Future<List<Map<String, dynamic>>> getVehiculos() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/vehiculos'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Vehículos obtenidos');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener vehículos');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener vehículos: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getMisVehiculos() async {
    final prefs = await SharedPreferences.getInstance();

    final role = (prefs.getString('role') ?? '').toUpperCase();
    final userId = prefs.getString('user_id');

    debugPrint('🚦 getMisVehiculos => role=$role userId=$userId');

    if (userId == null || userId.isEmpty) {
      debugPrint('❌ No hay user_id guardado');
      return [];
    }

    final todosVehiculos = await getVehiculos();

    if (role == 'EMPRESA' || role == 'ADMIN' || role == 'SECRETARIA') {
      return todosVehiculos;
    }

    final filtrados = todosVehiculos.where((vehiculo) {
      if (role == 'CONDUCTOR') {
        final conductor = vehiculo['conductor'];

        if (conductor is Map) {
          final usuario = conductor['usuario'];

          final idUsuario =
              conductor['idUsuario']?.toString() ??
              conductor['id_usuario']?.toString() ??
              (usuario is Map ? usuario['id']?.toString() : null) ??
              (usuario is Map ? usuario['idUsuario']?.toString() : null);

          return idUsuario == userId;
        }
      }

      if (role == 'PROPIETARIO') {
        final propietario = vehiculo['propietario'];

        if (propietario is Map) {
          final usuario = propietario['usuario'];

          final idUsuario =
              propietario['idUsuario']?.toString() ??
              propietario['id_usuario']?.toString() ??
              (usuario is Map ? usuario['id']?.toString() : null) ??
              (usuario is Map ? usuario['idUsuario']?.toString() : null);

          return idUsuario == userId;
        }
      }

      return false;
    }).toList();

    debugPrint('✅ Vehículos filtrados para $role: ${filtrados.length}');
    return filtrados;
  }

  /// Obtiene detalle de un vehículo específico
  /// GET /api/vehiculos/{id}/detalle
  static Future<Map<String, dynamic>?> getVehiculoDetalle(
    int vehiculoId,
  ) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos/$vehiculoId/detalle'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado');
      } else {
        debugPrint('❌ Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener detalle de vehículo: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> createVehiculo({
    required int idPropietario,
    required String placa,
    required String vin,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
    required int kilometrajeActual,
  }) async {
    try {
      final headers = await _buildHeaders();

      final body = {
        'idPropietario': idPropietario,
        'placa': placa.trim().toUpperCase(),
        'vin': vin.trim(),
        'marca': marca.trim(),
        'modelo': modelo.trim(),
        'anio': anio,
        'color': color.trim(),
        'kilometrajeActual': kilometrajeActual,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/vehiculos'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error creando vehículo ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error creando vehículo: $e');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> updateVehiculo({
    required int vehiculoId,
    String? placa,
    String? vin,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
    int? kilometrajeActual,
  }) async {
    try {
      final headers = await _buildHeaders();

      final body = <String, dynamic>{
        if (placa != null && placa.trim().isNotEmpty)
          'placa': placa.trim().toUpperCase(),
        if (vin != null && vin.trim().isNotEmpty) 'vin': vin.trim(),
        if (marca != null && marca.trim().isNotEmpty) 'marca': marca.trim(),
        if (modelo != null && modelo.trim().isNotEmpty) 'modelo': modelo.trim(),
        if (anio != null) 'anio': anio,
        if (color != null && color.trim().isNotEmpty) 'color': color.trim(),
        if (kilometrajeActual != null) 'kilometrajeActual': kilometrajeActual,
      };

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/vehiculos/$vehiculoId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error editando vehículo ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error editando vehículo: $e');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> asignarConductorVehiculo({
    required int vehiculoId,
    required int idConductor,
  }) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/vehiculos/$vehiculoId/asignar-conductor'),
            headers: headers,
            body: jsonEncode({'idConductor': idConductor}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error asignando conductor ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error asignando conductor: $e');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> desasignarConductorVehiculo({
    required int vehiculoId,
  }) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .put(
            Uri.parse(
              '$_baseUrl/api/vehiculos/$vehiculoId/desasignar-conductor',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error desasignando conductor ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error desasignando conductor: $e');
    }

    return null;
  }

  // ==================== DOCUMENTOS ====================

  /// Obtiene documentos de un usuario específico
  /// GET /api/documentos?idUsuario={userId}
  static Future<List<Map<String, dynamic>>> getDocumentos({
    required String userId,
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/documentos?idUsuario=$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Documentos obtenidos para usuario $userId');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado');
      } else {
        debugPrint('❌ Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener documentos: $e');
    }
    return [];
  }

  /// Obtiene documentos de la empresa con filtros
  /// GET /api/documentos/tabla?estado=&diasMaximos=
  static Future<List<Map<String, dynamic>>> getDocumentosEmpresa({
    String? estado,
    int? diasMaximos,
  }) async {
    try {
      final headers = await _buildHeaders();

      String url = '$_baseUrl/api/documentos/tabla';
      final List<String> queryParams = [];

      if (estado != null && estado.isNotEmpty) {
        queryParams.add('estado=$estado');
      }
      if (diasMaximos != null) {
        queryParams.add('diasMaximos=$diasMaximos');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      debugPrint('📡 Obteniendo documentos desde: $url');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Documentos obtenidos');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener documentos');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener documentos: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getMisDocumentos() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final role = prefs.getString('role') ?? '';
    final conductorId = prefs.getString('conductor_id');
    final propietarioId = prefs.getString('propietario_id');

    if (userId == null || userId.isEmpty) {
      debugPrint('❌ No hay user_id guardado');
      return [];
    }

    debugPrint(
      '📄 [getMisDocumentos] Role: $role, UserId: $userId, ConductorId: $conductorId, PropietarioId: $propietarioId',
    );

    final List<Map<String, dynamic>> documentosFinales = [];

    // 1. Documentos personales del usuario
    final personales = await getDocumentos(userId: userId);
    documentosFinales.addAll(personales);
    debugPrint(
      '📄 [getMisDocumentos] Documentos personales: ${personales.length}',
    );

    // 2. Documentos de vehículos asignados al conductor/propietario
    if (role.toLowerCase() == 'conductor' ||
        role.toLowerCase() == 'propietario') {
      final vehiculos = await getMisVehiculos();
      debugPrint(
        '📄 [getMisDocumentos] Vehículos del $role: ${vehiculos.length}',
      );

      for (final vehiculo in vehiculos) {
        final dynamic rawId = vehiculo['idVehiculo'] ?? vehiculo['id'];
        final int? vehiculoId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');

        if (vehiculoId == null) {
          debugPrint('⚠️ No se pudo obtener ID del vehículo: $vehiculo');
          continue;
        }

        final docsVehiculo = await getDocumentosPorVehiculo(vehiculoId);
        documentosFinales.addAll(docsVehiculo);
        debugPrint(
          '📄 [getMisDocumentos] Documentos vehículo $vehiculoId: ${docsVehiculo.length}',
        );
      }
    }

    // 3. Evitar duplicados por id_documento
    final Map<String, Map<String, dynamic>> unicos = {};

    for (int i = 0; i < documentosFinales.length; i++) {
      final doc = documentosFinales[i];

      final id = doc['idDocumento'] ?? doc['id_documento'] ?? doc['id'];

      final key =
          id?.toString() ??
          '${doc['nombre'] ?? doc['nombreTipoDocumento'] ?? 'doc'}-${doc['fechaVencimiento'] ?? i}';

      unicos[key] = doc;
    }
    debugPrint(
      '✅ [getMisDocumentos] Total documentos finales: ${unicos.length} para rol $role',
    );

    return unicos.values.toList();
  }

  /// Obtiene documentos próximos a vencer (en X días)
  static Future<List<Map<String, dynamic>>> getDocumentosProximosAVencer({
    int diasMaximos = 30,
  }) async {
    return getDocumentosEmpresa(diasMaximos: diasMaximos);
  }

  /// Obtiene documentos vencidos
  static Future<List<Map<String, dynamic>>> getDocumentosVencidos() async {
    return getDocumentosEmpresa(estado: 'vencido');
  }

  /// Obtiene documentos de un vehículo específico
  /// GET /api/vehiculos/{vehiculoId}/documentos
  static Future<List<Map<String, dynamic>>> getDocumentosPorVehiculo(
    int vehiculoId,
  ) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos/$vehiculoId/documentos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al obtener documentos del vehículo: $e');
    }
    return [];
  }

  // ==================== CONDUCTORES ====================

  /// Obtiene lista de conductores de la empresa
  /// GET /api/conductores
  static Future<List<Map<String, dynamic>>> getConductores() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/conductores'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Conductores obtenidos');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener conductores');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener conductores: $e');
    }
    return [];
  }

  // ==================== PROPIETARIOS ====================

  /// Obtiene lista de propietarios de la empresa
  /// GET /api/propietarios
  static Future<List<Map<String, dynamic>>> getPropietarios() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/propietarios'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Propietarios obtenidos');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener propietarios');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener propietarios: $e');
    }
    return [];
  }

  // ==================== USUARIOS ====================

  /// Obtiene lista de usuarios de la empresa
  /// GET /api/usuarios
  static Future<List<Map<String, dynamic>>> getUsuarios() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/usuarios'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Usuarios obtenidos');

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener usuarios');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener usuarios: $e');
    }
    return [];
  }

  /// Obtiene usuario actual del backend
  static Future<Map<String, dynamic>?> getUsuarioActual() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/usuarios/actual'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener usuario actual: $e');
    }
    return null;
  }

  // ==================== PERFIL ====================

  /// Obtiene el perfil del usuario autenticado
  /// GET /api/usuarios/me
  static Future<Map<String, dynamic>?> getMiPerfil() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/usuarios/me'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Perfil obtenido');
        return decoded is Map<String, dynamic> ? decoded : null;
      } else {
        debugPrint('❌ Error perfil ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener perfil: $e');
    }

    return null;
  }

  /// Actualiza el perfil del usuario autenticado
  /// PUT /api/usuarios/me
  static Future<bool> updateMiPerfil({
    required String nombre,
    required String apellido,
    required String telefono,
    required String direccion,
  }) async {
    try {
      final headers = await _buildHeaders();

      final body = {
        'nombre': nombre.trim(),
        'apellido': apellido.trim(),
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
      };

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/usuarios/me'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint('✅ Perfil actualizado');
        return true;
      }

      debugPrint(
        '❌ Error actualizando perfil ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error al actualizar perfil: $e');
    }

    return false;
  }

  /// Cambia la contraseña del usuario autenticado
  /// PUT /api/usuarios/me/password
  static Future<Map<String, dynamic>> cambiarMiPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/usuarios/me/password'),
            headers: headers,
            body: jsonEncode({
              'passwordActual': passwordActual,
              'passwordNueva': passwordNueva,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        debugPrint('✅ Contraseña actualizada');
        return {
          'ok': true,
          'mensaje':
              decoded['mensaje'] ?? 'Contraseña actualizada correctamente',
        };
      }

      return {
        'ok': false,
        'error': decoded['error'] ?? 'No se pudo cambiar la contraseña',
      };
    } catch (e) {
      debugPrint('❌ Error al cambiar contraseña: $e');
      return {'ok': false, 'error': 'Error de conexión'};
    }
  }

  /// Obtiene la empresa del usuario autenticado
  /// GET /api/empresas/me
  static Future<Map<String, dynamic>?> getMiEmpresa() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/empresas/me'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Empresa actual obtenida');
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint('❌ Error empresa ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('❌ Error al obtener empresa actual: $e');
    }

    return null;
  }

  /// Actualiza la empresa del usuario autenticado
  /// PUT /api/empresas/me
  static Future<bool> updateMiEmpresa({
    required String nombreEmpresa,
    required String telefono,
    required String direccion,
  }) async {
    try {
      final headers = await _buildHeaders();

      final body = {
        'nombreEmpresa': nombreEmpresa.trim(),
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
      };

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/empresas/me'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint('✅ Empresa actualizada');
        return true;
      }

      debugPrint(
        '❌ Error actualizando empresa ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error al actualizar empresa: $e');
    }

    return false;
  }

  // ==================== CERTIFICACIONES / SOLICITUDES ====================

  static Future<List<Map<String, dynamic>>> getTiposSolicitud() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/tipos-solicitud'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded
              .map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              )
              .toList();
        }
      }

      debugPrint(
        '❌ Error tipos solicitud ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error getTiposSolicitud: $e');
    }

    return [];
  }

  static Future<List<Map<String, dynamic>>> getSolicitudes() async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(Uri.parse('$_baseUrl/api/solicitudes'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint('📌 SOLICITUDES RAW: ${response.body}');

        final decoded = jsonDecode(response.body);
        debugPrint('📌 SOLICITUDES RAW: ${response.body}');

        if (decoded is List) {
          return decoded
              .map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              )
              .toList();
        }
      }

      debugPrint(
        '❌ Error solicitudes ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error getSolicitudes: $e');
    }

    return [];
  }

  static Future<List<Map<String, dynamic>>> getHistorialSolicitud(
    int solicitudId,
  ) async {
    try {
      final headers = await _buildHeaders();

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/solicitudes/$solicitudId/historial'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded
              .map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              )
              .toList();
        }
      }

      debugPrint('❌ Error historial ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('❌ Error getHistorialSolicitud: $e');
    }

    return [];
  }

  static Future<Map<String, dynamic>?> crearSolicitud({
    required int tipoSolicitudId,
    required String descripcion,
    int? vehiculoId,
    int? documentoId,
  }) async {
    try {
      final token = await _getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/solicitudes'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['tipoSolicitudId'] = tipoSolicitudId.toString();

      if (descripcion.trim().isNotEmpty) {
        request.fields['descripcion'] = descripcion.trim();
      }

      if (vehiculoId != null) {
        request.fields['vehiculoId'] = vehiculoId.toString();
      }

      if (documentoId != null) {
        request.fields['documentoId'] = documentoId.toString();
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final decoded = jsonDecode(responseBody);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error crearSolicitud ${streamedResponse.statusCode}: $responseBody',
      );
    } catch (e) {
      debugPrint('❌ Error crearSolicitud: $e');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> subirArchivoSolicitud({
    required int solicitudId,
    required String descripcion,
    required PlatformFile archivo,
    int? tipoSolicitudId,
  }) async {
    try {
      final token = await _getToken();

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/api/solicitudes/$solicitudId'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['descripcion'] = descripcion;

      if (tipoSolicitudId != null) {
        request.fields['tipoSolicitudId'] = tipoSolicitudId.toString();
      }

      if (archivo.bytes == null) {
        debugPrint('❌ El archivo no tiene bytes');
        return null;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          archivo.bytes!,
          filename: archivo.name,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error subirArchivoSolicitud ${streamedResponse.statusCode}: $responseBody',
      );
    } catch (e) {
      debugPrint('❌ Error subirArchivoSolicitud: $e');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> responderSolicitudConArchivo({
    required int solicitudId,
    required String estado,
    required String observaciones,
    PlatformFile? archivo,
  }) async {
    try {
      final token = await _getToken();

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/api/solicitudes/$solicitudId/estado'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['estado'] = estado;
      request.fields['observaciones'] = observaciones;

      if (archivo != null && archivo.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'archivo',
            archivo.bytes!,
            filename: archivo.name,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error responderSolicitudConArchivo ${streamedResponse.statusCode}: $responseBody',
      );
    } catch (e) {
      debugPrint('❌ Error responderSolicitudConArchivo: $e');
    }

    return null;
  }

  static Future<bool> cambiarEstadoSolicitud({
    required int solicitudId,
    required String estado,
    required String observaciones,
  }) async {
    try {
      final headers = await _buildHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/solicitudes/$solicitudId/estado'),
            headers: headers,
            body: jsonEncode({
              'estado': estado,
              'observaciones': observaciones,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return true;
      }

      debugPrint(
        '❌ Error cambiarEstadoSolicitud ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error cambiarEstadoSolicitud: $e');
    }

    return false;
  }

  // ==================== MANTENIMIENTOS ====================

  /// Obtiene mantenimientos según el rol del usuario
  /// Para empresa: todos los mantenimientos de la empresa
  /// Para conductor/propietario: sus mantenimientos específicos
  static Future<List<Map<String, dynamic>>> getMantenimientos({
    required String role,
    String? userId,
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);
      final String url = '$_baseUrl/api/mantenimientos';

      debugPrint('🔧 [getMantenimientos] URL: $url');
      debugPrint('🔧 [getMantenimientos] Role: $role, UserId: $userId');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🔧 [getMantenimientos] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint(
          '🔧 [getMantenimientos] Decoded type: ${decoded.runtimeType}',
        );

        List<dynamic> mantenimientosList = [];

        if (decoded is List) {
          mantenimientosList = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            mantenimientosList = decoded['data'];
          } else if (decoded['content'] is List) {
            mantenimientosList = decoded['content'];
          } else if (decoded['mantenimientos'] is List) {
            mantenimientosList = decoded['mantenimientos'];
          } else if (decoded['items'] is List) {
            mantenimientosList = decoded['items'];
          }
        }

        debugPrint('🔧 [getMantenimientos] Body completo: ${response.body}');
        debugPrint(
          '🔧 [getMantenimientos] Lista final: ${mantenimientosList.length}',
        );

        debugPrint(
          '✅ [getMantenimientos] Retornando ${mantenimientosList.length} mantenimientos',
        );
        return List<Map<String, dynamic>>.from(
          mantenimientosList.map(
            (item) => item is Map<String, dynamic> ? item : <String, dynamic>{},
          ),
        );
      } else {
        debugPrint(
          '❌ [getMantenimientos] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getMantenimientos] Excepción: $e');
    }
    return [];
  }

  /// Crea un nuevo mantenimiento
  /// POST /api/mantenimientos
  static Future<Map<String, dynamic>?> createMantenimiento({
    required int vehiculoId,
    required int tipoId,
    required String estado,
    DateTime? fechaSugerida,
    DateTime? fechaProgramada,
    DateTime? fechaRealizada,
    int? kilometraje,
    int? costo,
    String? taller,
    String? observaciones,
    String? prioridad,
    List<String>? documentos,
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);
      headers['Content-Type'] = 'application/json';

      final body = <String, dynamic>{
        'vehiculoId': vehiculoId,
        'tipoMantenimientoId': tipoId,
        if (estado.trim().isNotEmpty) 'estado': estado.trim().toUpperCase(),

        if (fechaSugerida != null)
          'fechaSugerida': fechaSugerida.toIso8601String().split('T')[0],

        if (fechaProgramada != null)
          'fechaProgramada': fechaProgramada.toIso8601String().split('T')[0],

        if (fechaRealizada != null)
          'fechaRealizado': fechaRealizada.toIso8601String().split('T')[0],

        if (kilometraje != null) 'kilometraje': kilometraje,
        if (costo != null) 'costo': costo,
        if (taller != null && taller.isNotEmpty) 'taller': taller,

        if (observaciones != null && observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
      };

      debugPrint('🔧 [createMantenimiento] Body: $body');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/mantenimientos'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('🔧 [createMantenimiento] Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ [createMantenimiento] Mantenimiento creado: $decoded');
        return decoded is Map<String, dynamic> ? decoded : null;
      } else {
        debugPrint(
          '❌ [createMantenimiento] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [createMantenimiento] Excepción: $e');
    }
    return null;
  }

  /// Actualiza un mantenimiento existente
  /// PUT /api/mantenimientos/{id}
  static Future<Map<String, dynamic>?> updateMantenimiento({
    required int mantenimientoId,
    DateTime? fechaRealizada,
    int? kilometraje,
    int? costo,
    String? taller,
    String? observaciones,
    String? prioridad,
    String? estado,
    String? userId,
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);
      headers['Content-Type'] = 'application/json';

      final body = <String, dynamic>{
        if (fechaRealizada != null)
          'fechaRealizado': fechaRealizada.toIso8601String().split('T')[0],
        if (kilometraje != null) 'kilometraje': kilometraje,
        if (costo != null) 'costo': costo,
        if (taller != null && taller.trim().isNotEmpty) 'taller': taller.trim(),
        if (observaciones != null && observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
      };

      debugPrint('🔧 [updateMantenimiento] ID: $mantenimientoId, Body: $body');

      final String url =
          '$_baseUrl/api/mantenimientos/$mantenimientoId/realizar';
      final response = await http
          .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      debugPrint('🔧 [updateMantenimiento] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint(
          '✅ [updateMantenimiento] Mantenimiento actualizado: $decoded',
        );
        return decoded is Map<String, dynamic> ? decoded : null;
      } else {
        debugPrint(
          '❌ [updateMantenimiento] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [updateMantenimiento] Excepción: $e');
    }
    return null;
  }

  /// Edita un mantenimiento existente (para programar o modificar)
  /// PUT /api/mantenimientos/{id}
  static Future<Map<String, dynamic>?> editMantenimiento({
    required int mantenimientoId,
    DateTime? fechaSugerida,
    DateTime? fechaProgramada,
    DateTime? fechaRealizada,
    int? kilometraje,
    int? costo,
    String? taller,
    String? observaciones,
    String? prioridad,
    String? estado,
    String? userId,
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);
      headers['Content-Type'] = 'application/json';

      final body = <String, dynamic>{
        if (fechaSugerida != null)
          'fechaSugerida': fechaSugerida.toIso8601String().split('T')[0],
        if (fechaProgramada != null)
          'fechaProgramada': fechaProgramada.toIso8601String().split('T')[0],
        if (fechaRealizada != null)
          'fechaRealizado': fechaRealizada.toIso8601String().split('T')[0],
        if (kilometraje != null) 'kilometraje': kilometraje,
        if (costo != null) 'costo': costo,
        if (taller != null && taller.trim().isNotEmpty) 'taller': taller.trim(),
        if (observaciones != null && observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
        if (prioridad != null && prioridad.trim().isNotEmpty)
          'prioridad': prioridad.trim(),
        if (estado != null) 'estado': estado,
      };

      debugPrint('🔧 [editMantenimiento] ID: $mantenimientoId, Body: $body');

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/mantenimientos/$mantenimientoId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('🔧 [editMantenimiento] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ [editMantenimiento] Mantenimiento editado: $decoded');
        return decoded is Map<String, dynamic> ? decoded : null;
      } else {
        debugPrint(
          '❌ [editMantenimiento] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [editMantenimiento] Excepción: $e');
    }
    return null;
  }

  /// Obtiene tipos de mantenimiento
  /// GET /api/mantenimientos/tipos
  static Future<List<Map<String, dynamic>>> getTiposMantenimiento({
    String? token,
  }) async {
    try {
      final headers = await _buildHeaders(token: token);

      final url = Uri.parse('$_baseUrl/api/tipos-mantenimiento');

      debugPrint('🔧 [getTiposMantenimiento] URL: $url');
      debugPrint(
        '🔧 [getTiposMantenimiento] Token: ${token != null ? "SÍ" : "NO"}',
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🔧 [getTiposMantenimiento] Status: ${response.statusCode}');
      debugPrint('🔧 [getTiposMantenimiento] Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded
              .map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              )
              .toList();
        }

        if (decoded is Map && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              )
              .toList();
        }
      } else {
        debugPrint(
          '❌ [getTiposMantenimiento] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getTiposMantenimiento] Excepción: $e');
    }

    return [];
  }

  /// Obtiene vehículos según el rol
  /// Para empresa: todos los vehículos
  /// Para conductor/propietario: sus vehículos asignados
  static Future<List<Map<String, dynamic>>> getVehiculosPorRol({
    required String role,
    String? userId,
    String? token,
  }) async {
    try {
      if (role.toLowerCase() == 'empresa') {
        // Para empresa, obtener todos los vehículos
        final headers = await _buildHeaders(token: token);
        final response = await http
            .get(Uri.parse('$_baseUrl/api/vehiculos'), headers: headers)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is List) {
            return List<Map<String, dynamic>>.from(
              decoded.map(
                (item) =>
                    item is Map<String, dynamic> ? item : <String, dynamic>{},
              ),
            );
          }
        }
      } else if (role.toLowerCase() == 'conductor' && userId != null) {
        // Usar el método existente de document_service
        return await DocumentService.getVehiculosPorConductor(
          conductorId: int.tryParse(userId) ?? 0,
          token: token,
        );
      } else if (role.toLowerCase() == 'propietario' && userId != null) {
        // Usar el método existente de document_service
        return await DocumentService.getVehiculosPorPropietario(
          propietarioId: int.tryParse(userId) ?? 0,
          token: token,
        );
      }
    } catch (e) {
      debugPrint('❌ [getVehiculosPorRol] Excepción: $e');
    }
    return [];
  }
}
