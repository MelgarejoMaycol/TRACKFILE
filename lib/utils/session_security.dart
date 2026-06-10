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
  const primaryColor = Color(0xFF3330BE);
  const surfaceColor = Color(0xFFF8FAFF);
  const titleColor = Color(0xFF12163F);
  const bodyColor = Color(0xFF3D4268);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: primaryColor, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sesion cerrada',
              style: TextStyle(
                color: titleColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Debimos cerrar su sesion por seguridad porque no fue posible cargar sus datos. Inicie sesion nuevamente para continuar.',
        style: TextStyle(color: bodyColor, fontSize: 15, height: 1.45),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () async {
              await clearStoredSession();
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!context.mounted) return;
              context.go('/login');
            },
            child: const Text('Aceptar'),
          ),
        ),
      ],
    ),
  );
}
