import 'dart:async';
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
      
      debugPrint('📡 Obteniendo documentos de empresa desde: $url');
      
      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('📄 Respuesta recibida, parseando documentos...');
        
        if (decoded is List) {
          final List<Map<String, dynamic>> docs = List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ Se obtuvieron ${docs.length} documentos de la empresa');
          return docs;
        }
        if (decoded is Map && decoded['data'] is List) {
          final List<Map<String, dynamic>> docs = List<Map<String, dynamic>>.from(
            decoded['data'].map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ Se obtuvieron ${docs.length} documentos de la empresa (con envolvente data)');
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
      // Todos los roles usan el mismo endpoint: /api/documentos/tabla
      // El frontend filtra según el rol
      debugPrint('📡 Obteniendo todos los documentos desde /api/documentos/tabla');
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
    int? personaIdUsuario, // ID de usuario de la persona (conductor/propietario)
    String? token,
    List<int>? fileBytes, // Bytes del archivo (para web)
  }) async {
    try {
      debugPrint('📤 DocumentService.uploadDocument() iniciado');
      debugPrint('   URL: $_baseUrl/api/documentos');
      debugPrint('   Token presente: ${token?.isNotEmpty == true}');
      debugPrint('   Usando bytes: ${fileBytes != null ? "sí (${fileBytes.length} bytes)" : "no"}');
      debugPrint('   personaId: $personaId');
      debugPrint('   personaIdUsuario: $personaIdUsuario');

      // En web usar bytes directamente, en nativo intentar leer del filesystem
      final file = fileBytes ?? await _readFile(filePath);
      if (file == null) {
        debugPrint('❌ No se pudo leer el archivo: $filePath');
        return null;
      }
      debugPrint('   Archivo: ${file.length} bytes');

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
      if (vehicleId != null && vehicleId > 0) {
        request.fields['idVehiculo'] = vehicleId.toString();
        debugPrint('   ✅ idVehiculo enviado: $vehicleId (vehículo seleccionado)');
      } else {
        debugPrint('   ⚠️ idVehiculo NO enviado (no seleccionado)');
      }
      
      // IMPORTANTE: La BD tiene restricción CHECK que NO permite ambos idVehiculo e idUsuario NOT NULL
      // Lógica: Si hay vehículo, NO enviar idUsuario (el propietario se deduce del vehículo)
      //        Si NO hay vehículo, enviamos idUsuario (documento asociado a usuario directo)
      if (vehicleId == null || vehicleId == 0) {
        // Sin vehículo: enviar idUsuario
        if (personaIdUsuario != null) {
          request.fields['idUsuario'] = personaIdUsuario.toString();
          debugPrint('   ✅ idUsuario enviado: $personaIdUsuario (usuario sin vehículo)');
        } else if (personaId != null) {
          // Fallback: si no tenemos idUsuario, enviar el id
          request.fields['idUsuario'] = personaId.toString();
          debugPrint('   ✅ idUsuario enviado: $personaId (id como fallback)');
        } else {
          debugPrint('   ⚠️ idUsuario NO enviado (no hay persona seleccionada)');
        }
      } else {
        // Con vehículo: NO enviar idUsuario (se deduce del vehículo)
        debugPrint('   ⚠️ idUsuario NO enviado (vehículo ya tiene propietario asignado)');
      }
      
      request.fields['idTipo'] = documentTypeId.toString();
      request.fields['area'] = area;
      request.fields['fechaVencimiento'] = expiryDate.toIso8601String().split('T')[0];
      
      if (observations != null && observations.isNotEmpty) {
        request.fields['observaciones'] = observations;
      }
      
      // Enviar responsableUsuarioId: el usuario autenticado (quien sube el documento)
      if (responsibleUserId != null && responsibleUserId != 0) {
        request.fields['responsableUsuarioId'] = responsibleUserId.toString();
        debugPrint('   responsableUsuarioId enviado: $responsibleUserId (usuario autenticado)');
      } else {
        debugPrint('   ⚠️ responsableUsuarioId NO enviado (no hay usuario autenticado)');
      }
      
      // NOTA: personaId NO se envía al backend, es solo para control en frontend

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
    
    debugPrint('📋 [getDocumentTypes] Retornando ${documentTypes.length} tipos de documento');
    for (int i = 0; i < documentTypes.length; i++) {
      debugPrint('   [$i] ID: ${documentTypes[i]['id']}, Nombre: ${documentTypes[i]['nombre']}');
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
      debugPrint('🔍 [getConductores] Response body (primeros 500 chars): ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');

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
      } else if (response.statusCode == 500) {
        debugPrint('🔴 [getConductores] ERROR 500 en servidor - Probable causa: Usuario no tiene empresa asociada');
        debugPrint('   ⚠️ Verifica que iniciaste sesión como EMPRESA, no como PROPIETARIO o CONDUCTOR');
        debugPrint('   Response: ${response.body}');
        throw Exception('Error del servidor (500): No se pudo obtener los conductores. Verifica que la empresa esté correctamente configurada.');
      } else {
        debugPrint('❌ [getConductores] Error ${response.statusCode}: ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('❌ [getConductores] Timeout: No se pudo conectar con el servidor');
      throw Exception('Tiempo de espera agotado: No se pudo conectar con el servidor.');
    } catch (e, stackTrace) {
      debugPrint('❌ [getConductores] Excepción: $e');
      debugPrint('❌ [getConductores] Stack trace: $stackTrace');
      
      // Si es un error de conexión o similar
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Error de conexión: No se pudo conectar con el servidor. Verifica que el servidor esté activo.');
      }
      
      rethrow;
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
      debugPrint('🔍 [getPropietarios] Response body (primeros 500 chars): ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');

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
      } else if (response.statusCode == 500) {
        debugPrint('🔴 [getPropietarios] ERROR 500 en servidor');
        debugPrint('   Response: ${response.body}');
        throw Exception('Error del servidor (500): No se pudo obtener los propietarios.');
      } else {
        debugPrint('❌ [getPropietarios] Error ${response.statusCode}: ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('❌ [getPropietarios] Timeout: No se pudo conectar con el servidor');
      throw Exception('Tiempo de espera agotado: No se pudo conectar con el servidor.');
    } catch (e, stackTrace) {
      debugPrint('❌ [getPropietarios] Excepción: $e');
      debugPrint('❌ [getPropietarios] Stack trace: $stackTrace');
      
      // Si es un error de conexión o similar
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Error de conexión: No se pudo conectar con el servidor. Verifica que el servidor esté activo.');
      }
      
      rethrow;
    }
    return [];
  }

  /// Obtiene todos los usuarios (conductores + propietarios + otros) ligados a la empresa actual
  static Future<List<Map<String, dynamic>>> getUsuariosEmpresa({String? token}) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/usuarios');
      
      debugPrint('🔍 [getUsuariosEmpresa] URL: $url');
      debugPrint('🔍 [getUsuariosEmpresa] Token: ${token?.isNotEmpty == true ? "presente" : "NULO/VACÍO"}');
      
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🔍 [getUsuariosEmpresa] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('🔍 [getUsuariosEmpresa] Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          debugPrint('✅ [getUsuariosEmpresa] Es una List con ${decoded.length} elementos');
          
          final result = List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ [getUsuariosEmpresa] Retornando ${result.length} usuarios');
          return result;
        } else if (decoded is Map && decoded['data'] is List) {
          debugPrint('✅ [getUsuariosEmpresa] Response es Map con campo data');
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          return result;
        }
      } else {
        debugPrint('❌ [getUsuariosEmpresa] Error ${response.statusCode}: ${response.body}');
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
      
      debugPrint('🚗 [getVehiculosPorConductor] Obteniendo vehículos para conductor ID: $conductorId');
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('🚗 [getVehiculosPorConductor] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          debugPrint('🚗 [getVehiculosPorConductor] Total vehículos en respuesta: ${decoded.length}');
          
          // Filtrar vehículos que tienen este conductor asignado
          final vehiculosFiltrados = <Map<String, dynamic>>[];
          
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              debugPrint('   ⚠️ Skip: item no es Map');
              continue;
            }
            
            debugPrint('   📋 Analizando vehículo: ${item['placa']}');
            
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
            debugPrint('      Conductor ID en JSON: $idCond (tipo: ${idCond.runtimeType})');
            debugPrint('      Conductor ID buscado: $conductorId (tipo: ${conductorId.runtimeType})');
            
            if (idCond == null) {
              debugPrint('      ❌ Conductor ID es null');
              continue;
            }
            
            try {
              final idCondInt = idCond is int ? idCond : int.parse(idCond.toString());
              final match = idCondInt == conductorId;
              
              debugPrint('      Comparación: $idCondInt == $conductorId = $match');
              
              if (match) {
                debugPrint('✅ [getVehiculosPorConductor] ¡COINCIDENCIA ENCONTRADA!');
                debugPrint('   - Placa: ${item['placa']}');
                debugPrint('   - ID Vehículo: ${item['id']}');
                vehiculosFiltrados.add(item);
              }
            } catch (e) {
              debugPrint('      ❌ Error parseando ID: $e');
            }
          }

          debugPrint('✅ [getVehiculosPorConductor] Total encontrados: ${vehiculosFiltrados.length}');
          
          return vehiculosFiltrados;
        }
      } else {
        debugPrint('❌ [getVehiculosPorConductor] Error ${response.statusCode}: ${response.body}');
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
      
      debugPrint('🚗 [getVehiculosPorPropietario] Obteniendo vehículos para propietario ID: $propietarioId');
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('🚗 [getVehiculosPorPropietario] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          debugPrint('🚗 [getVehiculosPorPropietario] Total vehículos en respuesta: ${decoded.length}');
          
          // Filtrar vehículos que pertenecen a este propietario
          final vehiculosFiltrados = <Map<String, dynamic>>[];
          
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              debugPrint('   ⚠️ Skip: item no es Map');
              continue;
            }
            
            debugPrint('   📋 Analizando vehículo: ${item['placa']}');
            
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
            debugPrint('      Propietario ID en JSON: $idProp (tipo: ${idProp.runtimeType})');
            debugPrint('      Propietario ID buscado: $propietarioId (tipo: ${propietarioId.runtimeType})');
            
            if (idProp == null) {
              debugPrint('      ❌ Propietario ID es null');
              continue;
            }
            
            try {
              final idPropInt = idProp is int ? idProp : int.parse(idProp.toString());
              final match = idPropInt == propietarioId;
              
              debugPrint('      Comparación: $idPropInt == $propietarioId = $match');
              
              if (match) {
                debugPrint('✅ [getVehiculosPorPropietario] ¡COINCIDENCIA ENCONTRADA!');
                debugPrint('   - Placa: ${item['placa']}');
                debugPrint('   - ID Vehículo: ${item['id']}');
                vehiculosFiltrados.add(item);
              }
            } catch (e) {
              debugPrint('      ❌ Error parseando ID: $e');
            }
          }

          debugPrint('✅ [getVehiculosPorPropietario] Total encontrados: ${vehiculosFiltrados.length}');
          
          return vehiculosFiltrados;
        }
      } else {
        debugPrint('❌ [getVehiculosPorPropietario] Error ${response.statusCode}: ${response.body}');
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
      
      debugPrint('🚗 [getAllVehicles] Obteniendo todos los vehículos');
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/vehiculos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          debugPrint('✅ [getAllVehicles] Se obtuvieron ${decoded.length} vehículos');
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
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

  /// Edita un documento existente
  static Future<void> updateDocument({
    required int documentoId,
    required int idTipo,
    required String? area,
    required DateTime fechaVencimiento,
    required String? observaciones,
    int? idVehiculo, // ID del vehículo si el documento es de vehículo
    int? idUsuario, // ID del usuario si el documento es personal
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token no disponible');
      }

      final headers = _buildHeaders(token);
      headers['Content-Type'] = 'application/json';

      // Enviar todos los campos necesarios para la validación de permisos
      final Map<String, dynamic> bodyMap = {
        'idTipo': idTipo,
        'area': area ?? '',
        'fechaVencimiento': fechaVencimiento.toString().split(' ')[0], // formato YYYY-MM-DD
        'observaciones': observaciones ?? '',
        // Incluir referencia al vehículo o usuario si aplica
        if (idVehiculo != null) 'idVehiculo': idVehiculo,
        if (idUsuario != null) 'idUsuario': idUsuario,
      };

      final requestBody = jsonEncode(bodyMap);

      debugPrint('📝 Editando documento $documentoId');
      debugPrint('   Body: $requestBody');

      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/documentos/$documentoId'),
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('   Response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Documento $documentoId editado exitosamente');
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
  static Future<List<Map<String, dynamic>>> getVehiculos({String? token}) async {
    try {
      final headers = _buildHeaders(token);
      final url = Uri.parse('$_baseUrl/api/vehiculos');
      
      debugPrint('🚗 [getVehiculos] Obteniendo todos los vehículos desde: $url');
      
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('🚗 [getVehiculos] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('🚗 [getVehiculos] Decoded type: ${decoded.runtimeType}');
        
        if (decoded is List) {
          debugPrint('✅ [getVehiculos] Retornando ${decoded.length} vehículos');
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ [getVehiculos] Retornando ${result.length} vehículos (con envolvente data)');
          return result;
        }
      } else if (response.statusCode == 500) {
        debugPrint('🔴 [getVehiculos] ERROR 500');
      } else {
        debugPrint('❌ [getVehiculos] Error ${response.statusCode}: ${response.body}');
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
      final url = Uri.parse('$_baseUrl/api/documentos/tabla?diasMaximos=$diasMaximos');
      
      debugPrint('📄 [getDocumentosProximosAVencer] Obteniendo documentos que vencen en $diasMaximos días');
      
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('📄 [getDocumentosProximosAVencer] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        if (decoded is List) {
          debugPrint('✅ [getDocumentosProximosAVencer] Retornando ${decoded.length} documentos');
          return List<Map<String, dynamic>>.from(
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        } else if (decoded is Map && decoded['data'] is List) {
          final result = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
          debugPrint('✅ [getDocumentosProximosAVencer] Retornando ${result.length} documentos (con envolvente data)');
          return result;
        }
      } else {
        debugPrint('❌ [getDocumentosProximosAVencer] Error ${response.statusCode}: ${response.body}');
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
}

Future<dynamic> import(String libName) async {
  throw UnsupportedError('Use conditional imports instead');
}
