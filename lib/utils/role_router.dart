import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/roles/admin_screen.dart';
import '../screens/roles/conductor_screen.dart';
import '../screens/roles/empresa_screen.dart';
import '../screens/roles/propietario_screen.dart';
import '../screens/roles/secretaria_screen.dart';
import '../services/api_link.dart';
import '../services/api_service.dart';

Widget? screenForRole(Map<String, dynamic> userData) {
  final String role = (userData['rol'] as String? ?? '').toUpperCase();
  final dynamic rawCompany = userData['empresa'];
  final Map<String, dynamic>? company = rawCompany is Map<String, dynamic>
      ? Map<String, dynamic>.from(rawCompany)
      : rawCompany is Map
      ? Map<String, dynamic>.from(rawCompany.cast<String, dynamic>())
      : null;
  switch (role) {
    case 'ADMIN':
      return const AdminScreen();
    case 'EMPRESA':
      return EmpresaScreen(
        key: ValueKey('empresa_${userData['id']}_${userData['token']}'),
        usuario: userData,
        empresa: company,
      );
    case 'PROPIETARIO':
      return PropietarioScreen(
        key: ValueKey('propietario_${userData['id']}_${userData['token']}'),
        userId: userData['id']?.toString(),
        personName: _fullName(userData),
        companyName: company?['nombreEmpresa']?.toString() ?? '',
      );
    case 'CONDUCTOR':
      return ConductorScreen(
        key: ValueKey('conductor_${userData['id']}_${userData['token']}'),
        userId: userData['id']?.toString(),
        personName: _fullName(userData),
        companyName: company?['nombreEmpresa']?.toString() ?? '',
      );
    case 'SECRETARIA':
      return const SecretariaScreen();
    default:
      return null;
  }
}

String _fullName(Map<String, dynamic> user) {
  final nombre = user['nombre']?.toString() ?? '';
  final apellido = user['apellido']?.toString() ?? '';
  return [nombre, apellido].where((part) => part.isNotEmpty).join(' ').trim();
}

Future<void> persistSession(Map<String, dynamic> userData) async {
  final prefs = await SharedPreferences.getInstance();
  final rawUser = jsonEncode(userData);
  await prefs.setString('auth_user', rawUser);

  // Guardar el user_id
  final userId = userData['id']?.toString();
  if (userId != null && userId.isNotEmpty) {
    await prefs.setString('user_id', userId);
  }

  // Guardar el role
  final role = userData['rol']?.toString().toUpperCase();
  if (role != null && role.isNotEmpty) {
    await prefs.setString('role', role);
  }

  // Guardar conductor_id si es conductor
  final conductorId =
      userData['conductor_id']?.toString() ??
      userData['conductorId']?.toString();
  if (conductorId != null && conductorId.isNotEmpty) {
    await prefs.setString('conductor_id', conductorId);
  } else if (role?.toUpperCase() == 'CONDUCTOR' && userId != null) {
    // Si es conductor pero no tenemos el ID, buscarlo en el backend
    final foundId = await _findConductorIdByUserId(userId, userData['token']);
    if (foundId != null) {
      await prefs.setString('conductor_id', foundId);
      debugPrint('🚗 Conductor ID encontrado y guardado: $foundId');
    }
  }

  // Guardar propietario_id si es propietario
  final propietarioId =
      userData['propietario_id']?.toString() ??
      userData['propietarioId']?.toString();
  if (propietarioId != null && propietarioId.isNotEmpty) {
    await prefs.setString('propietario_id', propietarioId);
  } else if (role?.toUpperCase() == 'PROPIETARIO' && userId != null) {
    // Si es propietario pero no tenemos el ID, buscarlo en el backend
    final foundId = await _findPropietarioIdByUserId(userId, userData['token']);
    if (foundId != null) {
      await prefs.setString('propietario_id', foundId);
      debugPrint('👨‍💼 Propietario ID encontrado y guardado: $foundId');
    }
  }

  // Obtener el JWT token (que viene en el campo 'token' de la respuesta del backend)
  final tokenValue = userData['token']?.toString();
  if (tokenValue != null && tokenValue.isNotEmpty) {
    await prefs.setString('auth_token', tokenValue);
    await prefs.setString('token', tokenValue);
    ApiService.setTokenCache(tokenValue);
    ApiService.startAutoRefreshToken();
  } else {
    debugPrint('⚠️ No se encontró token en userData');
  }
}

Future<String?> _findConductorIdByUserId(String userId, dynamic token) async {
  try {
    final baseUrl = getApiLink();
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.toString()}';
    }

    final response = await http
        .get(Uri.parse('$baseUrl/api/conductores'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final conductores = decoded is List ? decoded : [];

      for (final conductor in conductores) {
        final idUsuario =
            conductor['id_usuario']?.toString() ??
            conductor['idUsuario']?.toString();
        if (idUsuario == userId) {
          final conductorId =
              conductor['id']?.toString() ??
              conductor['id_conductor']?.toString();
          if (conductorId != null) {
            debugPrint(
              '✅ Conductor encontrado: usuario=$userId, conductor=$conductorId',
            );
            return conductorId;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error buscando conductor: $e');
  }
  return null;
}

Future<String?> _findPropietarioIdByUserId(String userId, dynamic token) async {
  try {
    final baseUrl = getApiLink();
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.toString()}';
    }

    final response = await http
        .get(Uri.parse('$baseUrl/api/propietarios'), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final propietarios = decoded is List ? decoded : [];

      for (final propietario in propietarios) {
        final idUsuario =
            propietario['id_usuario']?.toString() ??
            propietario['idUsuario']?.toString();
        if (idUsuario == userId) {
          final propietarioId =
              propietario['id']?.toString() ??
              propietario['id_propietario']?.toString();
          if (propietarioId != null) {
            debugPrint(
              '✅ Propietario encontrado: usuario=$userId, propietario=$propietarioId',
            );
            return propietarioId;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error buscando propietario: $e');
  }
  return null;
}

Future<Map<String, dynamic>?> loadSession() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('auth_user');

  if (raw == null || raw.isEmpty) return null;

  try {
    final decoded = jsonDecode(raw);

    if (decoded is Map<String, dynamic>) {
      await ApiService.refreshSessionToken();
      ApiService.startAutoRefreshToken();

      final updatedRaw = prefs.getString('auth_user');
      if (updatedRaw != null && updatedRaw.isNotEmpty) {
        final updatedDecoded = jsonDecode(updatedRaw);
        if (updatedDecoded is Map<String, dynamic>) {
          return updatedDecoded;
        }
      }

      return decoded;
    }
  } catch (_) {
    return null;
  }

  return null;
}

Future<void> clearSession() async {
  final prefs = await SharedPreferences.getInstance();

  ApiService.clearTokenCache();

  await prefs.remove('auth_user');
  await prefs.remove('auth_token');
  await prefs.remove('token');
  await prefs.remove('user_id');
  await prefs.remove('usuario_id');
  await prefs.remove('role');
  await prefs.remove('rol');
  await prefs.remove('empresa_id');
  await prefs.remove('conductor_id');
  await prefs.remove('propietario_id');
}
