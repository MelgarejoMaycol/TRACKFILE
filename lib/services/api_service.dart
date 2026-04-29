import 'dart:async';
import 'dart:convert';

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
