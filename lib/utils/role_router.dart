import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/roles/admin_screen.dart';
import '../screens/roles/conductor_screen.dart';
import '../screens/roles/empresa_screen.dart';
import '../screens/roles/propietario_screen.dart';
import '../screens/roles/secretaria_screen.dart';

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
      return EmpresaScreen(usuario: userData, empresa: company);
    case 'PROPIETARIO':
      return PropietarioScreen(
        userId: userData['id']?.toString(),
        personName: _fullName(userData),
        companyName: company?['nombreEmpresa']?.toString() ?? '',
      );
    case 'CONDUCTOR':
      return ConductorScreen(
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
    debugPrint('👤 User ID guardado: $userId');
  }

  // Obtener el JWT token (que viene en el campo 'token' de la respuesta del backend)
  final tokenValue = userData['token'];
  if (tokenValue != null && tokenValue.isNotEmpty) {
    await prefs.setString('auth_token', tokenValue);
    debugPrint('🔐 Token JWT guardado: ${tokenValue.substring(0, 20)}...');
  } else {
    debugPrint('⚠️ No se encontró token en userData');
    await prefs.setString('auth_token', 'session_active');
  }
}

Future<Map<String, dynamic>?> loadSession() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('auth_user');
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<void> clearSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_user');
  await prefs.remove('auth_token');
  await prefs.remove('user_id');
}
