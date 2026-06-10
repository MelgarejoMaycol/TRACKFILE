import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

Future<void> clearStoredSession() async {
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

Future<void> showSecurityLogoutDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sesion cerrada'),
      content: const Text(
        'Debimos cerrar su sesion por seguridad porque no fue posible cargar sus datos. Inicie sesion nuevamente para continuar.',
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            await clearStoredSession();
            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            if (!context.mounted) return;
            context.go('/login');
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}
