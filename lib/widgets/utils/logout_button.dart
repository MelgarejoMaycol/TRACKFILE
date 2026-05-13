import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackfile/services/notification/notificaciones_realtime_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    NotificacionesRealtimeService.stop();
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('auth_token');
    await prefs.remove('token');
    await prefs.remove('rol');
    await prefs.remove('role');
    await prefs.remove('user_id');
    await prefs.remove('usuario_id');
    await prefs.remove('empresa_id');
    await prefs.remove('conductor_id');
    await prefs.remove('propietario_id');

    if (!context.mounted) return;

    context.goNamed('login');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _logout(context),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Cerrar sesión'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFBFC7F5),
        foregroundColor: const Color(0xFF1F255E),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}