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
import '../widgets/certificados/certificaciones.dart';
import '../widgets/documents/documentos_screen.dart';
// Widgets / pantallas internas
import '../widgets/inicio.dart';
import '../widgets/mantenimientos/mantenimientos.dart';
import '../widgets/mensajes/mensajes.dart';
import '../widgets/pagos/pagos.dart';
import '../widgets/users/empresa.dart';
import '../widgets/users/gestion_personas_widget.dart';
import '../widgets/users/perfil.dart';

class DashboardSessionLoader extends StatelessWidget {
  final String role;

  const DashboardSessionLoader({super.key, required this.role});

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
            return EmpresaScreen(usuario: session, empresa: empresa);

          case 'propietario':
            return PropietarioScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
            );

          case 'conductor':
            return ConductorScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
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

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('auth_token') ?? prefs.getString('token');

    final rol = prefs.getString('role') ?? prefs.getString('rol');

    final String rutaActual = state.uri.toString();

    final bool enLogin = rutaActual == '/login';
    final bool enOnboarding = rutaActual == '/onboarding';

    // ❌ NO hay sesión → login
    if (token == null || token.isEmpty) {
      if (enLogin || enOnboarding) return null;
      return '/login';
    }

    // ✅ YA logueado → no quedarse en login
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

    // Ruta base del dashboard
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      redirect: (context, state) async {
        final prefs = await SharedPreferences.getInstance();
        final rol =
            prefs.getString('role') ?? prefs.getString('rol') ?? 'empresa';
        return '/dashboard/${rol.toLowerCase()}';
      },
      routes: [
        GoRoute(
          path: 'empresa',
          name: 'dashboard_empresa',
          builder: (context, state) =>
              const DashboardSessionLoader(role: 'empresa'),
        ),
        GoRoute(
          path: 'propietario',
          name: 'dashboard_propietario',
          builder: (context, state) =>
              const DashboardSessionLoader(role: 'propietario'),
        ),
        GoRoute(
          path: 'conductor',
          name: 'dashboard_conductor',
          builder: (context, state) =>
              const DashboardSessionLoader(role: 'conductor'),
        ),
        GoRoute(
          path: 'admin',
          name: 'dashboard_admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: 'secretaria',
          name: 'dashboard_secretaria',
          builder: (context, state) =>
              const DashboardSessionLoader(role: 'secretaria'),
        ),

        // Pantallas internas
        GoRoute(
          path: 'inicio',
          name: 'inicio',
          builder: (context, state) => const InicioWidget(),
        ),
        GoRoute(
          path: ':role/perfil',
          name: 'perfil',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            return PerfilWidget(role: role);
          },
        ),
        GoRoute(
          path: 'documentos',
          name: 'documentos',
          builder: (context, state) => const DocumentosScreen(),
        ),
        GoRoute(
          path: ':role/mantenimientos',
          name: 'mantenimientos',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            return MantenimientosWidget(role: role);
          },
        ),
        GoRoute(
          path: 'mensajes',
          name: 'mensajes',
          builder: (context, state) => const MensajesWidget(),
        ),
        GoRoute(
          path: ':role/pagos',
          name: 'pagos',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            return PagosWidget(role: role);
          },
        ),
        GoRoute(
          path: ':role/certificaciones',
          name: 'certificaciones',
          builder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            return CertificacionesWidget(role: role);
          },
        ),
        GoRoute(
          path: 'empresa-info',
          name: 'empresa_info',
          builder: (context, state) => const EmpresaWidget(),
        ),
        GoRoute(
          path: 'propietarios',
          name: 'propietarios',
          builder: (context, state) =>
              const DashboardSessionLoader(role: 'propietario'),
        ),
        GoRoute(
          path: 'gestion-personas',
          name: 'gestion_personas',
          builder: (context, state) => const GestionPersonasWidget(),
        ),
      ],
    ),
  ],
);
