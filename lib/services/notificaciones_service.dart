import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './api_link.dart';

class NotificacionesService {
  static final http.Client _client = http.Client();

  static String? _tokenCache;

  static String get baseUrl =>
      '${getApiLink().replaceAll(RegExp(r"/+$"), "")}/api';

  static Future<String?> _token() async {
    if (_tokenCache != null && _tokenCache!.isNotEmpty) {
      return _tokenCache;
    }

    final prefs = await SharedPreferences.getInstance();

    _tokenCache =
        prefs.getString('auth_token') ??
        prefs.getString('token') ??
        prefs.getString('jwt') ??
        prefs.getString('access_token');

    return _tokenCache;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _token();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _get(String url) async {
    return _client
        .get(Uri.parse(url), headers: await _headers())
        .timeout(const Duration(seconds: 20));
  }

  static Future<http.Response> _patch(String url) async {
    return _client
        .patch(Uri.parse(url), headers: await _headers())
        .timeout(const Duration(seconds: 20));
  }

  static Exception _error(String accion, http.Response response) {
    return Exception(
      'Error al $accion: ${response.statusCode} - ${response.body}',
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data.map((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        return <String, dynamic>{};
      }).toList();
    }

    if (data is Map && data['data'] is List) {
      return _asMapList(data['data']);
    }

    if (data is Map && data['content'] is List) {
      return _asMapList(data['content']);
    }

    return [];
  }

  static bool _esPendiente(Map<String, dynamic> n) {
    final estado = '${n['estado'] ?? n['status'] ?? ''}'.toUpperCase();
    final leida = n['leida'] == true;

    return !leida && estado != 'LEIDA' && estado != 'LEÍDA' && estado != 'READ';
  }

  static Future<List<Map<String, dynamic>>> listar() async {
    final response = await _get('$baseUrl/notificaciones');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _asMapList(data);
    }

    throw _error('listar notificaciones', response);
  }

  static Future<List<Map<String, dynamic>>> listarNoLeidas() async {
    final response = await _get('$baseUrl/notificaciones/no-leidas');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _asMapList(data);
    }

    final todas = await listar();
    return todas.where(_esPendiente).toList();
  }

  static Future<int> contador() async {
    final response = await _get('$baseUrl/notificaciones/contador');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return int.tryParse('${data['noLeidas'] ?? data['pendientes'] ?? 0}') ??
          0;
    }

    final notificaciones = await listar();
    return notificaciones.where(_esPendiente).length;
  }

  static Future<Map<String, dynamic>?> marcarComoLeida(String id) async {
    final response = await _patch('$baseUrl/notificaciones/$id/leer');

    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    if (response.statusCode == 204) return null;

    throw _error('marcar como leída', response);
  }

  static Future<void> marcarTodasComoLeidas() async {
    final response = await _patch('$baseUrl/notificaciones/leer-todas');

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw _error('marcar todas como leídas', response);
  }

  static void limpiarCacheToken() {
    _tokenCache = null;
  }
}
