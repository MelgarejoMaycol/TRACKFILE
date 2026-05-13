import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './api_link.dart';

class NotificacionesService {
  static String get baseUrl =>
      '${getApiLink().replaceAll(RegExp(r"/+$"), "")}/api';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('token') ??
        prefs.getString('auth_token') ??
        prefs.getString('jwt') ??
        prefs.getString('access_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _token();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Exception _error(String accion, http.Response response) {
    return Exception(
      'Error al $accion: ${response.statusCode} - ${response.body}',
    );
  }

  static Future<List<Map<String, dynamic>>> listar() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }

    throw _error('listar notificaciones', response);
  }

  static Future<List<Map<String, dynamic>>> listarNoLeidas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/no-leidas'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }

    throw _error('listar notificaciones no leídas', response);
  }

  static Future<int> contador() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/contador'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return int.tryParse('${data['noLeidas'] ?? 0}') ?? 0;
    }

    throw _error('obtener contador', response);
  }

  static Future<Map<String, dynamic>?> marcarComoLeida(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificaciones/$id/leer'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    if (response.statusCode == 204) return null;

    throw _error('marcar como leída', response);
  }

  static Future<void> marcarTodasComoLeidas() async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificaciones/leer-todas'),
      headers: await _headers(),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw _error('marcar todas como leídas', response);
  }
}