import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './api_link.dart';

class NotificacionesService {
  static String get baseUrl =>
      '${getApiLink().replaceAll(RegExp(r"/+$"), "")}/api';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _token();

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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

    throw Exception('Error al listar notificaciones: ${response.statusCode}');
  }

  static Future<int> contador() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/contador'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['noLeidas'] ?? 0;
    }

    throw Exception('Error al obtener contador: ${response.statusCode}');
  }

  static Future<void> marcarComoLeida(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificaciones/$id/leer'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al marcar como leída: ${response.statusCode}');
    }
  }

  static Future<void> marcarTodasComoLeidas() async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificaciones/leer-todas'),
      headers: await _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Error al marcar todas como leídas: ${response.statusCode}',
      );
    }
  }
}
