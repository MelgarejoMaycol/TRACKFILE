import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/services/notifications/notificaciones_realtime_service.dart';
import 'package:trackfile/services/notificaciones_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    NotificacionesRealtimeService.stop();
    NotificacionesService.limpiarCacheToken();
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    if (!context.mounted) return;

    context.go('/login');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
