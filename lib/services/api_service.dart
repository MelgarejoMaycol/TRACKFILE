import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import './api_link.dart';

class ApiService {
  // URL base del servidor
  static String get _baseUrl {
    return _customBaseUrl ?? getApiLink(); // Siempre usar la URL remota compilada por ApiConfig
  }

  static String? _customBaseUrl;

  /// Establece una URL base personalizada
  static void setBaseUrl(String url) {
    _customBaseUrl = url;
    debugPrint('🌐 BaseURL configurada a: $url');
  }

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
          .get(
            Uri.parse('$_baseUrl/api/vehiculos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Vehículos obtenidos');
        
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
  static Future<Map<String, dynamic>?> getVehiculoDetalle(int vehiculoId) async {
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
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
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
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Documentos obtenidos');
        
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

  /// Obtiene documentos próximos a vencer (en X días)
  static Future<List<Map<String, dynamic>>> getDocumentosProximosAVencer(
      {int diasMaximos = 30}) async {
    return getDocumentosEmpresa(diasMaximos: diasMaximos);
  }

  /// Obtiene documentos vencidos
  static Future<List<Map<String, dynamic>>> getDocumentosVencidos() async {
    return getDocumentosEmpresa(estado: 'vencido');
  }

  /// Obtiene documentos de un vehículo específico
  /// GET /api/vehiculos/{vehiculoId}/documentos
  static Future<List<Map<String, dynamic>>> getDocumentosPorVehiculo(
      int vehiculoId) async {
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
            decoded.map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
          );
        }
        if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(
            decoded['data'].map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{}),
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
          .get(
            Uri.parse('$_baseUrl/api/conductores'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Conductores obtenidos');
        
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
          .get(
            Uri.parse('$_baseUrl/api/propietarios'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Propietarios obtenidos');
        
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
          .get(
            Uri.parse('$_baseUrl/api/usuarios'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Usuarios obtenidos');
        
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
          .get(
            Uri.parse('$_baseUrl/api/usuarios/actual'),
            headers: headers,
          )
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
}
