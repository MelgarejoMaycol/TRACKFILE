import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontendproyecto/screens/login_screen.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key, this.expand = true});

  final bool expand;

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _loading = false;

  Future<void> _handleLogout() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user');
      await prefs.remove('auth_token');

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.route,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $error')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget button = FilledButton.icon(
      onPressed: _loading ? null : _handleLogout,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(_loading ? 'Cerrando…' : 'Cerrar sesión'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );

    if (!widget.expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
