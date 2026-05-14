import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens principales
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';

// Dashboards por rol
import '../screens/roles/admin_screen.dart';
import '../screens/roles/conductor_screen.dart';
import '../screens/roles/empresa_screen.dart';
import '../screens/roles/propietario_screen.dart';
import '../screens/roles/secretaria_screen.dart';

import '../utils/role_router.dart';

class DashboardSessionLoader extends StatelessWidget {
  final String role;
  final String? section;

  const DashboardSessionLoader({
    super.key,
    required this.role,
    this.section,
  });

  String _text(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: loadSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF131760),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;

        if (session == null) {
          return const LoginScreen();
        }

        final empresa = _map(session['empresa']);

        final userId = _text(session['usuarioId']).isNotEmpty
            ? _text(session['usuarioId'])
            : _text(session['id']);

        final nombre = _text(session['nombre']);
        final apellido = _text(session['apellido']);

        final nombreCompleto = [
          nombre,
          apellido,
        ].where((e) => e.trim().isNotEmpty).join(' ').trim();

        final nombreEmpresa = _text(empresa?['nombreEmpresa']).isNotEmpty
            ? _text(empresa?['nombreEmpresa'])
            : _text(empresa?['nombre']);

        switch (role.toLowerCase()) {
          case 'empresa':
            return EmpresaScreen(
              usuario: session,
              empresa: empresa,
              initialSection: section,
            );

          case 'propietario':
            return PropietarioScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
              initialSection: section,
            );

          case 'conductor':
            return ConductorScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
              initialSection: section,
            );

          case 'admin':
            return const AdminScreen();

          case 'secretaria':
            return const SecretariaScreen();

          default:
            return const LoginScreen();
        }
      },
    );
  }
}

String _sectionFromUrl(String sectionUrl) {
  switch (sectionUrl.toLowerCase()) {
    case 'inicio':
      return 'Inicio';
    case 'documentos':
      return 'Documentos';
    case 'perfil':
      return 'Perfil';
    case 'mensajes':
      return 'Mensajes';
    case 'certificaciones':
      return 'Certificaciones';
    case 'vehiculos':
      return 'Vehículos';
    case 'mantenimientos':
      return 'Mantenimientos';
    case 'empresa-info':
      return 'Empresa';
    case 'conductores':
      return 'Conductores';
    case 'propietarios':
      return 'Propietarios';
    default:
      return 'Inicio';
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('auth_token') ?? prefs.getString('token');
    final rol = prefs.getString('role') ?? prefs.getString('rol');

    final rutaActual = state.uri.path;

    final bool enLogin = rutaActual == '/login';
    final bool enOnboarding = rutaActual == '/onboarding';

    if (token == null || token.isEmpty) {
      if (enLogin || enOnboarding) return null;
      return '/login';
    }

    if (enLogin || enOnboarding) {
      final rolRuta = (rol ?? 'empresa').toLowerCase();
      return '/dashboard/$rolRuta';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      redirect: (context, state) async {
        final rutaActual = state.uri.path;

        if (rutaActual != '/dashboard') {
          return null;
        }

        final prefs = await SharedPreferences.getInstance();
        final rol =
            prefs.getString('role') ?? prefs.getString('rol') ?? 'empresa';

        return '/dashboard/${rol.toLowerCase()}';
      },
      routes: [
        GoRoute(
          path: ':role',
          name: 'dashboard_role',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';

            if (role == 'admin') {
              return const AdminScreen();
            }

            if (role == 'secretaria') {
              return const SecretariaScreen();
            }

            return DashboardSessionLoader(
              role: role,
              section: 'Inicio',
            );
          },
        ),

        GoRoute(
          path: ':role/:section',
          name: 'dashboard_section',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            final sectionUrl = state.pathParameters['section'] ?? 'inicio';
            final section = _sectionFromUrl(sectionUrl);

            if (role == 'admin') {
              return const AdminScreen();
            }

            if (role == 'secretaria') {
              return const SecretariaScreen();
            }

            return DashboardSessionLoader(
              role: role,
              section: section,
            );
          },
        ),
      ],
    ),
  ],
);