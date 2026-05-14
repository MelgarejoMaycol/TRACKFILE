import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './api_link.dart';

class DocumentService {
  static final http.Client _client = http.Client();
  static String? _tokenCache;
  // URL base - siempre usa Onrender
  static String get _baseUrl => getApiLink();

  /// Obtiene los documentos del usuario desde el backend
  static Future<List<Map<String, dynamic>>> getDocuments({
    required String userId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);

      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/documentos?idUsuario=$userId'),
            headers: headers,
          )
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

  /// Obtiene TODOS los documentos de la empresa del usuario autenticado
  /// Retorna documentos de todos los usuarios/conductores/propietarios ligados a la empresa
  static Future<List<Map<String, dynamic>>> getCompanyDocuments({
    String? token,
    String? estado, // 'vigente' o 'vencido'
    int? diasMaximos, // Documentos que vencen en X días
  }) async {
    try {
      final headers = _buildHeaders(token);

      // Construir URL con parámetros opcionales
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

      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          final List<Map<String, dynamic>> docs =
              List<Map<String, dynamic>>.from(
                decoded.map(
                  (item) =>
                      item is Map<String, dynamic> ? item : <String, dynamic>{},
                ),
              );
          return docs;
        }
        if (decoded is Map && decoded['data'] is List) {
          final List<Map<String, dynamic>> docs =
              List<Map<String, dynamic>>.from(
                decoded['data'].map(
                  (item) =>
                      item is Map<String, dynamic> ? item : <String, dynamic>{},
                ),
              );
          return docs;
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ No autorizado para obtener documentos de empresa');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener documentos de empresa: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getDocumentDetail({
    required int documentoId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);

      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/documentos/$documentoId/detalle'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      debugPrint(
        '❌ Error detalle documento ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error getDocumentDetail: $e');
    }

    return null;
  }

  /// Obtiene documentos según el rol del usuario
  /// Para empresa: todos los documentos de la empresa
  /// Para conductor/propietario: sus documentos específicos
  /// Nota: El backend solo tiene GET /api/documentos/tabla
  /// Frontend debe filtrar los documentos por usuario/vehículo
  static Future<List<Map<String, dynamic>>> getDocumentsByRole({
    required String role,
    String? userId,
    String? token,
  }) async {
    try {
      return await getCompanyDocuments(token: token);
    } catch (e) {
      debugPrint('❌ Error obteniendo documentos por rol: $e');
      return [];
    }
  }

  /// Sube un documento al backend
  static Future<Map<String, dynamic>?> uploadDocument({
    required String filePath,
    required String fileName,
    required int? vehicleId,
    required int documentTypeId,
    required String area,
    required DateTime expiryDate,
    String? observations,
    int? responsibleUserId,
    int? personaId,
    int?
    personaIdUsuario, // ID de usuario de la persona (conductor/propietario)
    String? token,
    List<int>? fileBytes, // Bytes del archivo (para web)
  }) async {
    try {
      // En web usar bytes directamente, en nativo intentar leer del filesystem
      final file = fileBytes ?? await _readFile(filePath);
      if (file == null) {
        debugPrint('❌ No se pudo leer el archivo: $filePath');
        return null;
      }

      // Para multipart requests, NO incluir Content-Type application/json
      // MultipartRequest lo maneja automáticamente
      final Map<String, String> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Crear multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/documentos'),
      );

      // Agregar headers
      request.headers.addAll(headers);

      // Agregar campos - NO enviar idVehiculo si es null
      if (vehicleId != null && vehicleId > 0) {
        request.fields['idVehiculo'] = vehicleId.toString();
      }

      // IMPORTANTE: La BD tiene restricción CHECK que NO permite ambos idVehiculo e idUsuario NOT NULL
      // Lógica: Si hay vehículo, NO enviar idUsuario (el propietario se deduce del vehículo)
      //        Si NO hay vehículo, enviamos idUsuario (documento asociado a usuario directo)
      if (vehicleId == null || vehicleId == 0) {
        // Sin vehículo: enviar idUsuario
        if (personaIdUsuario != null) {
          request.fields['idUsuario'] = personaIdUsuario.toString();
        } else if (personaId != null) {
          // Fallback: si no tenemos idUsuario, enviar el id
          request.fields['idUsuario'] = personaId.toString();
        } else {
          debugPrint(
            '   ⚠️ idUsuario NO enviado (no hay persona seleccionada)',
          );
        }
      } 

      request.fields['idTipo'] = documentTypeId.toString();
      request.fields['area'] = area;
      request.fields['fechaVencimiento'] = expiryDate.toIso8601String().split(
        'T',
      )[0];

      if (observations != null && observations.isNotEmpty) {
        request.fields['observaciones'] = observations;
      }

      // Enviar responsableUsuarioId: el usuario autenticado (quien sube el documento)
      if (responsibleUserId != null && responsibleUserId != 0) {
        request.fields['responsableUsuarioId'] = responsibleUserId.toString();
      } 
      // Agregar archivo
      request.files.add(
        http.MultipartFile.fromBytes('archivo', file, filename: fileName),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ Error 401: No autorizado (token inválido o ausente)');
      } else if (response.statusCode == 400) {
        debugPrint('❌ Error 400: Validación fallida');
        debugPrint('   Detalles: ${response.body}');
      } else if (response.statusCode == 500) {
        debugPrint('❌ Error 500: Error del servidor');
        debugPrint('   Detalles: ${response.body}');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Excepción: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
    return null;
  }

  /// Obtiene los tipos de documentos disponibles
  static Future<List<Map<String, dynamic>>> getDocumentTypes({
    String? token,
  }) async {
    // Lista de tipos de documento según la BD
    final List<Map<String, dynamic>> documentTypes = [
      {'id': 1, 'nombre': 'SOAT'},
      {'id': 2, 'nombre': 'TECNOMECANICA'},
      {'id': 3, 'nombre': 'LICENCIA'},
      {'id': 4, 'nombre': 'TARJETA_OPERACION'},
      {'id': 5, 'nombre': 'SEGURO'},
      {'id': 6, 'nombre': 'CONTRACTUAL'},
      {'id': 7, 'nombre': 'EXTRACONTRACTUAL'},
      {'id': 8, 'nombre': 'OTRO'},
      {'id': 9, 'nombre': 'CEDULA'},
      {'id': 10, 'nombre': 'PASAPORTE'},
      {'id': 11, 'nombre': 'RUT'},
      {'id': 12, 'nombre': 'POLIZA_TODO_RIESGO'},
      {'id': 13, 'nombre': 'CERTIFICADO_PROPIEDAD'},
      {'id': 14, 'nombre': 'PERMISO_CIRCULACION'},
    ];

    return documentTypes;
  }

  /// Obtiene los conductores asignados a la empresa actual
  static Future<List<Map<String, dynamic>>> getConductores({
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/conductores');
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          final result = List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        } else {
          debugPrint(
            '⚠️ [getConductores] Response no es List ni Map.data, es: ${decoded.runtimeType}',
          );
          debugPrint('   Contenido: $decoded');
        }
      } else if (response.statusCode == 500) {
        debugPrint(
          '🔴 [getConductores] ERROR 500 en servidor - Probable causa: Usuario no tiene empresa asociada',
        );
        debugPrint(
          '   ⚠️ Verifica que iniciaste sesión como EMPRESA, no como PROPIETARIO o CONDUCTOR',
        );
        throw Exception(
          'Error del servidor (500): No se pudo obtener los conductores. Verifica que la empresa esté correctamente configurada.',
        );
      } else {
        debugPrint(
          '❌ [getConductores] Error ${response.statusCode}: ${response.body}',
        );
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      debugPrint(
        '❌ [getConductores] Timeout: No se pudo conectar con el servidor',
      );
      throw Exception(
        'Tiempo de espera agotado: No se pudo conectar con el servidor.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [getConductores] Excepción: $e');
      debugPrint('❌ [getConductores] Stack trace: $stackTrace');

      // Si es un error de conexión o similar
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('ClientException')) {
        throw Exception(
          'Error de conexión: No se pudo conectar con el servidor. Verifica que el servidor esté activo.',
        );
      }

      rethrow;
    }
    return [];
  }

  /// Obtiene los propietarios asignados a la empresa actual
  static Future<List<Map<String, dynamic>>> getPropietarios({
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/propietarios');
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          final result = List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        }
      } else if (response.statusCode == 500) {
        debugPrint('🔴 [getPropietarios] ERROR 500 en servidor');
        throw Exception(
          'Error del servidor (500): No se pudo obtener los propietarios.',
        );
      } else {
        debugPrint(
          '❌ [getPropietarios] Error ${response.statusCode}: ${response.body}',
        );
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      debugPrint(
        '❌ [getPropietarios] Timeout: No se pudo conectar con el servidor',
      );
      throw Exception(
        'Tiempo de espera agotado: No se pudo conectar con el servidor.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [getPropietarios] Excepción: $e');
      debugPrint('❌ [getPropietarios] Stack trace: $stackTrace');

      // Si es un error de conexión o similar
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('ClientException')) {
        throw Exception(
          'Error de conexión: No se pudo conectar con el servidor. Verifica que el servidor esté activo.',
        );
      }

      rethrow;
    }
    return [];
  }

  /// Obtiene todos los usuarios (conductores + propietarios + otros) ligados a la empresa actual
  static Future<List<Map<String, dynamic>>> getUsuariosEmpresa({
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/usuarios');
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          final result = List<Map<String, dynamic>>.from(
            decoded.map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        }
      } else {
        debugPrint(
          '❌ [getUsuariosEmpresa] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getUsuariosEmpresa] Error: $e');
    }
    return [];
  }

  /// Obtiene los vehículos asignados a un conductor
  /// Llama a /api/vehiculos y filtra por conductor.id
  static Future<List<Map<String, dynamic>>> getVehiculosPorConductor({
    required int conductorId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/vehiculos'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          // Filtrar vehículos que tienen este conductor asignado
          final vehiculosFiltrados = <Map<String, dynamic>>[];

          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              debugPrint('   ⚠️ Skip: item no es Map');
              continue;
            }

            if (item['conductor'] == null) {
              debugPrint('      ❌ Sin conductor');
              continue;
            }

            final conductorObj = item['conductor'];
            if (conductorObj is! Map) {
              debugPrint('      ❌ Conductor no es Map');
              continue;
            }

            final idCond = conductorObj['id'];

            if (idCond == null) {
              debugPrint('      ❌ Conductor ID es null');
              continue;
            }

            try {
              final idCondInt = idCond is int
                  ? idCond
                  : int.parse(idCond.toString());
              final match = idCondInt == conductorId;

              if (match) {
                vehiculosFiltrados.add(item);
              }
            } catch (e) {
              debugPrint('      ❌ Error parseando ID: $e');
            }
          }

          return vehiculosFiltrados;
        }
      } else {
        debugPrint(
          '❌ [getVehiculosPorConductor] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getVehiculosPorConductor] Excepción: $e');
    }
    return [];
  }

  /// Obtiene los vehículos asignados a un propietario
  /// Llama a /api/vehiculos y filtra por propietario.id
  static Future<List<Map<String, dynamic>>> getVehiculosPorPropietario({
    required int propietarioId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/vehiculos'), headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          // Filtrar vehículos que pertenecen a este propietario
          final vehiculosFiltrados = <Map<String, dynamic>>[];

          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              debugPrint('   ⚠️ Skip: item no es Map');
              continue;
            }

            if (item['propietario'] == null) {
              debugPrint('      ❌ Sin propietario');
              continue;
            }

            final propietarioObj = item['propietario'];
            if (propietarioObj is! Map) {
              debugPrint('      ❌ Propietario no es Map');
              continue;
            }

            final idProp = propietarioObj['id'];

            if (idProp == null) {
              debugPrint('      ❌ Propietario ID es null');
              continue;
            }

            try {
              final idPropInt = idProp is int
                  ? idProp
                  : int.parse(idProp.toString());
              final match = idPropInt == propietarioId;

              if (match) {
                vehiculosFiltrados.add(item);
              }
            } catch (e) {
              debugPrint('      ❌ Error parseando ID: $e');
            }
          }

          return vehiculosFiltrados;
        }
      } else {
        debugPrint(
          '❌ [getVehiculosPorPropietario] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getVehiculosPorPropietario] Excepción: $e');
    }
    return [];
  }

  /// Obtiene TODOS los vehículos disponibles
  /// Útil para encontrar propietario y conductor de un vehículo específico
  static Future<List<Map<String, dynamic>>> getAllVehicles({
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final response = await _client
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
      } else {
        debugPrint('❌ [getAllVehicles] Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [getAllVehicles] Excepción: $e');
    }
    return [];
  }

  /// Obtiene el token guardado locally
  static Future<String?> getToken() async {
    if (_tokenCache != null && _tokenCache!.isNotEmpty) {
      return _tokenCache;
    }

    final prefs = await SharedPreferences.getInstance();
    _tokenCache = prefs.getString('auth_token');
    return _tokenCache;
  }

  /// Construye los headers con autenticación
  static Map<String, String> _buildHeaders(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Lee un archivo y devuelve sus bytes
  static Future<List<int>?> _readFile(String filePath) async {
    try {
      final file = await _getFile(filePath);
      if (file != null) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('❌ Error leyendo archivo: $e');
    }
    return null;
  }

  /// Edita un documento existente
  static Future<void> updateDocument({
    required int documentoId,
    required int idTipo,
    required String? area,
    required DateTime fechaVencimiento,
    required String? observaciones,
    int? idVehiculo, // ID del vehículo si el documento es de vehículo
    int? responsableUsuarioId, // ID del usuario responsable (quien edita)
    int? idUsuario, // ID del usuario propietario para documentos de usuario
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token no disponible');
      }

      final headers = _buildHeaders(token);
      headers['Content-Type'] = 'application/json';

      // Enviar solo los campos permitidos
      final Map<String, dynamic> bodyMap = {
        'idTipo': idTipo,
        'area': area ?? '',
        'fechaVencimiento': fechaVencimiento.toString().split(
          ' ',
        )[0], // formato YYYY-MM-DD
        'observaciones': observaciones ?? '',
        // Incluir vehículo o responsable según tipo de documento
        if (idVehiculo != null) 'idVehiculo': idVehiculo,
        if (responsableUsuarioId != null)
          'responsableUsuarioId': responsableUsuarioId,
        if (idUsuario != null) 'idUsuario': idUsuario,
      };

      final requestBody = jsonEncode(bodyMap);
      final response = await _client
          .put(
            Uri.parse('$_baseUrl/api/documentos/$documentoId'),
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) {
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401: No autorizado - Token inválido');
        throw Exception('No autorizado - Token inválido');
      } else if (response.statusCode == 403) {
        debugPrint('❌ 403: Permiso denegado. Response: ${response.body}');
        throw Exception('Permiso denegado');
      } else if (response.statusCode == 404) {
        debugPrint('❌ 404: Documento no encontrado');
        throw Exception('Documento no encontrado');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error editando documento: $e');
      rethrow;
    }
  }

  /// Obtiene todos los vehículos de la empresa
  static Future<List<Map<String, dynamic>>> getVehiculos({
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/vehiculos');
      final response = await _client
          .get(url, headers: headers)
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
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        }
      } else if (response.statusCode == 500) {
        debugPrint('🔴 [getVehiculos] ERROR 500');
      } else {
        debugPrint(
          '❌ [getVehiculos] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getVehiculos] Excepción: $e');
    }
    return [];
  }

  /// Obtiene documentos próximos a vencer con filtro de días
  static Future<List<Map<String, dynamic>>> getDocumentosProximosAVencer({
    int diasMaximos = 30,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse(
        '$_baseUrl/api/documentos/tabla?diasMaximos=$diasMaximos',
      );

      final response = await _client
          .get(url, headers: headers)
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
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (item) =>
                  item is Map<String, dynamic> ? item : <String, dynamic>{},
            ),
          );
          return result;
        }
      } else {
        debugPrint(
          '❌ [getDocumentosProximosAVencer] Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [getDocumentosProximosAVencer] Excepción: $e');
    }
    return [];
  }

  /// Obtiene File object desde diferentes plataformas
  static Future<File?> _getFile(String filePath) async {
    if (filePath.isEmpty) return null;

    try {
      if (kIsWeb) {
        // En web, file_picker devuelve bytes directamente
        return null;
      } else {
        // En mobile/desktop platforms, usamos dart:io File
        return File(filePath);
      }
    } catch (e) {
      debugPrint('❌ Error inicializando File: $e');
      return null;
    }
  }

  /// Actualiza el estado (activo/inactivo) de un documento
  /// Usualmente para deactivar un documento duplicado cuando se activa otro
  static Future<void> updateDocumentStatus({
    required int documentoId,
    required bool estado,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      headers['Content-Type'] = 'application/json';

      final Map<String, dynamic> bodyMap = {'estadoDocumento': estado};
      final requestBody = jsonEncode(bodyMap);

      final response = await _client
          .put(
            Uri.parse('$_baseUrl/api/documentos/$documentoId/status'),
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) {
      } else if (response.statusCode == 401) {
        debugPrint('❌ 401: No autorizado - Token inválido');
        throw Exception('No autorizado - Token inválido');
      } else if (response.statusCode == 404) {
        debugPrint('❌ 404: Documento no encontrado');
        throw Exception('Documento no encontrado');
      } else {
        debugPrint('❌ Error ${response.statusCode}: ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error actualizando estado del documento: $e');
      rethrow;
    }
  }
}

Future<dynamic> import(String libName) async {
  throw UnsupportedError('Use conditional imports instead');
}
