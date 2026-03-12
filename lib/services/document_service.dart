import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DocumentService {
  // Usar variable dinámica en lugar de constante
  static String get _baseUrl {
    // Por defecto usa localhost, pero puede ser sobrescrito
    return _customBaseUrl ?? 'http://localhost:8080';
  }

  static String? _customBaseUrl;

  /// Establece una URL base personalizada (ej: para IP en lugar de localhost)
  static void setBaseUrl(String url) {
    _customBaseUrl = url;
    debugPrint('🌐 BaseURL establecida a: $url');
  }

  /// Obtiene los documentos del usuario desde el backend
  static Future<List<Map<String, dynamic>>> getDocuments({
    required String userId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/documentos?idUsuario=$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
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
    String? token,
  }) async {
    try {
      debugPrint('📤 DocumentService.uploadDocument() iniciado');
      debugPrint('   URL: $_baseUrl/api/documentos');
      debugPrint('   Token presente: ${token?.isNotEmpty == true}');

      final file = await _readFile(filePath);
      if (file == null) {
        debugPrint('❌ No se pudo leer el archivo: $filePath');
        return null;
      }
      debugPrint('   Archivo leído: ${file.length} bytes');

      // Para multipart requests, NO incluir Content-Type application/json
      // MultipartRequest lo maneja automáticamente
      final Map<String, String> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      debugPrint('   Headers: $headers');

      // Crear multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/documentos'),
      );

      // Agregar headers
      request.headers.addAll(headers);

      // Agregar campos - NO enviar idVehiculo si es null
      if (vehicleId != null) {
        request.fields['idVehiculo'] = vehicleId.toString();
      }
      request.fields['idTipo'] = documentTypeId.toString();
      request.fields['area'] = area;
      request.fields['fechaVencimiento'] = expiryDate.toIso8601String().split('T')[0];
      
      if (observations != null && observations.isNotEmpty) {
        request.fields['observaciones'] = observations;
      }
      
      // Enviar responsableUsuarioId: SOLO el conductor/propietario seleccionado (personaId)
      // NO usar el usuario autenticado como fallback
      if (personaId != null) {
        request.fields['responsableUsuarioId'] = personaId.toString();
        debugPrint('   responsableUsuarioId enviado: $personaId (conductor/propietario seleccionado)');
      } else {
        debugPrint('   ⚠️ responsableUsuarioId NO enviado (no hay persona seleccionada)');
      }

      debugPrint('   Campos enviados:');
      request.fields.forEach((k, v) {
        debugPrint('     - $k: $v');
      });

      // Agregar archivo
      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          file,
          filename: fileName,
        ),
      );
      debugPrint('   Archivo multipart: $fileName');

      debugPrint('🔄 Enviando request...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📨 Respuesta recibida: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          debugPrint('✅ Documento subido exitosamente: $decoded');
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
  static Future<List<Map<String, dynamic>>> getDocumentTypes({String? token}) async {
    // Lista hardcodeada de tipos de documento
    // Los IDs se envían en orden: 1=SOAT, 2=TECNOMECANICA, 3=LICENCIA, 4=TARJETA_OPERACION,
    // 5=SEGURO, 6=CONTRACTUAL, 7=EXTRACONTRACTUAL, 8=OTRO
    final List<Map<String, dynamic>> documentTypes = [
      {'id': 1, 'nombre': 'SOAT'},
      {'id': 2, 'nombre': 'TECNOMECANICA'},
      {'id': 3, 'nombre': 'LICENCIA'},
      {'id': 4, 'nombre': 'TARJETA_OPERACION'},
      {'id': 5, 'nombre': 'SEGURO'},
      {'id': 6, 'nombre': 'CONTRACTUAL'},
      {'id': 7, 'nombre': 'EXTRACONTRACTUAL'},
      {'id': 8, 'nombre': 'OTRO'},
    ];
    
    debugPrint('📋 [getDocumentTypes] Retornando ${documentTypes.length} tipos de documento (hardcodeado)');
    for (int i = 0; i < documentTypes.length; i++) {
      debugPrint('   Tipo $i: ${documentTypes[i]}');
    }
    
    return documentTypes;
  }

  /// Obtiene los conductores asignados a la empresa actual
  static Future<List<Map<String, dynamic>>> getConductores({String? token}) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/conductores');
      
      debugPrint('🔍 [getConductores] URL: $url');
      debugPrint('🔍 [getConductores] Token: ${token?.isNotEmpty == true ? "presente (${token!.length} chars)" : "NULO/VACÍO"}');
      debugPrint('🔍 [getConductores] Headers: $headers');
      
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🔍 [getConductores] Status: ${response.statusCode}');
      debugPrint('🔍 [getConductores] Response body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('🔍 [getConductores] Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          debugPrint('✅ [getConductores] Es una List con ${decoded.length} elementos');
          
          // Imprimir estructura de cada elemento
          for (int i = 0; i < decoded.length && i < 3; i++) {
            debugPrint('🔍 [getConductores] Elemento $i: ${decoded[i]}');
            if (decoded[i] is Map) {
              debugPrint('   Keys: ${(decoded[i] as Map).keys.toList()}');
            }
          }
          
          final result = List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ [getConductores] Retornando ${result.length} conductores');
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          debugPrint('✅ [getConductores] Response es Map con campo data, la lista tiene ${(decoded['data'] as List).length} elementos');
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          return result;
        } else {
          debugPrint('⚠️ [getConductores] Response no es List ni Map.data, es: ${decoded.runtimeType}');
          debugPrint('   Contenido: $decoded');
        }
      } else {
        debugPrint('❌ [getConductores] Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [getConductores] Excepción: $e');
      debugPrint('❌ [getConductores] Stack trace: $stackTrace');
    }
    return [];
  }

  /// Obtiene los propietarios asignados a la empresa actual
  static Future<List<Map<String, dynamic>>> getPropietarios({String? token}) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/propietarios');
      
      debugPrint('🔍 [getPropietarios] URL: $url');
      debugPrint('🔍 [getPropietarios] Token: ${token?.isNotEmpty == true ? "presente (${token!.length} chars)" : "NULO/VACÍO"}');
      debugPrint('🔍 [getPropietarios] Headers: $headers');
      
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🔍 [getPropietarios] Status: ${response.statusCode}');
      debugPrint('🔍 [getPropietarios] Response body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('🔍 [getPropietarios] Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          debugPrint('✅ [getPropietarios] Es una List con ${decoded.length} elementos');
          
          // Imprimir estructura de cada elemento
          for (int i = 0; i < decoded.length && i < 3; i++) {
            debugPrint('🔍 [getPropietarios] Elemento $i: ${decoded[i]}');
            if (decoded[i] is Map) {
              debugPrint('   Keys: ${(decoded[i] as Map).keys.toList()}');
            }
          }
          
          final result = List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ [getPropietarios] Retornando ${result.length} propietarios');
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          debugPrint('✅ [getPropietarios] Response es Map con campo data, la lista tiene ${(decoded['data'] as List).length} elementos');
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          return result;
        } else {
          debugPrint('⚠️ [getPropietarios] Response no es List ni Map.data, es: ${decoded.runtimeType}');
          debugPrint('   Contenido: $decoded');
        }
      } else {
        debugPrint('❌ [getPropietarios] Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [getPropietarios] Excepción: $e');
      debugPrint('❌ [getPropietarios] Stack trace: $stackTrace');
    }
    return [];
  }

  /// Obtiene los vehículos asignados a un conductor
  static Future<List<Map<String, dynamic>>> getVehiculosPorConductor({
    required int conductorId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos/conductor/$conductorId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        }
      } else {
        debugPrint('❌ Error obteniendo vehículos del conductor ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener vehículos del conductor: $e');
    }
    return [];
  }

  /// Obtiene los vehículos asignados a un propietario (con info de conductores)
  static Future<List<Map<String, dynamic>>> getVehiculosPorPropietario({
    required int propietarioId,
    String? token,
  }) async {
    try {
      final headers = _buildHeaders(token);
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos/propietario/$propietarioId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        }
      } else {
        debugPrint('❌ Error obteniendo vehículos del propietario ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al obtener vehículos del propietario: $e');
    }
    return [];
  }

  /// Obtiene el token guardado locally
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
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
}

Future<dynamic> import(String libName) async {
  throw UnsupportedError('Use conditional imports instead');
}
