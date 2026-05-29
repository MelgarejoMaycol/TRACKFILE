import 'dart:async';

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
import '../widgets/android_download_prompt.dart';

class DashboardSessionLoader extends StatefulWidget {
  final String role;
  final String? section;
  final bool showAndroidPrompt;

  const DashboardSessionLoader({
    super.key,
    required this.role,
    this.section,
    this.showAndroidPrompt = false,
  });

  @override
  State<DashboardSessionLoader> createState() => _DashboardSessionLoaderState();
}

class _DashboardSessionLoaderState extends State<DashboardSessionLoader> {
  Future<Map<String, dynamic>?>? _sessionFuture;
  Map<String, dynamic>? _session;
  bool _downloadPromptScheduled = false;
  bool _securityDialogScheduled = false;
  bool _hadStoredSession = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSessionOnce();
  }

  Future<Map<String, dynamic>?> _loadSessionOnce() async {
    if (_session != null) return _session;

    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString('auth_user');
    final token = prefs.getString('auth_token') ?? prefs.getString('token');
    _hadStoredSession =
        (rawSession != null && rawSession.isNotEmpty) ||
        (token != null && token.isNotEmpty);

    try {
      final session = await loadSession().timeout(const Duration(seconds: 12));
      if (mounted) {
        _session = session;
      }
      return session;
    } on TimeoutException {
      if (_hadStoredSession) rethrow;
    } catch (_) {
      if (_hadStoredSession) rethrow;
    }

    return null;
  }

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

  void _scheduleAndroidDownloadPrompt() {
    if (_downloadPromptScheduled) return;
    _downloadPromptScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !AndroidDownloadPrompt.shouldShowForContext(context)) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final shouldShow =
          widget.showAndroidPrompt ||
          prefs.getBool(AndroidDownloadPrompt.pendingAfterLoginKey) == true;

      if (!shouldShow || !mounted) return;

      await prefs.remove(AndroidDownloadPrompt.pendingAfterLoginKey);

      if (!mounted) return;
      unawaited(
        AndroidDownloadPrompt.precacheImages(context).catchError((_) {}),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const AndroidDownloadPrompt(),
      );
    });
  }

  void _scheduleSecurityLogoutDialog() {
    if (_securityDialogScheduled) return;
    _securityDialogScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sesion cerrada'),
          content: const Text(
            'Cerramos su sesion por su seguridad. Inicie sesion nuevamente para continuar.',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await clearSession();
                if (!dialogCtx.mounted) return;
                Navigator.of(dialogCtx).pop();
                if (!mounted) return;
                context.go('/login');
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF131760),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data ?? _session;

        if (snapshot.hasError || (session == null && _hadStoredSession)) {
          _scheduleSecurityLogoutDialog();
          return const Scaffold(
            backgroundColor: Color(0xFF131760),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session == null) {
          return const LoginScreen();
        }

        _scheduleAndroidDownloadPrompt();

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

        switch (widget.role.toLowerCase()) {
          case 'empresa':
            return EmpresaScreen(
              usuario: session,
              empresa: empresa,
              initialSection: widget.section,
            );

          case 'propietario':
            return PropietarioScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
              initialSection: widget.section,
            );

          case 'conductor':
            return ConductorScreen(
              userId: userId,
              personName: nombreCompleto,
              companyName: nombreEmpresa,
              initialSection: widget.section,
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
    case 'solicitudes':
      return 'Solicitudes';
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
  initialLocation: '/onboarding',

  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('auth_token') ?? prefs.getString('token');
    final rol = prefs.getString('role') ?? prefs.getString('rol');

    final rutaActual = state.uri.path;

    final bool enLogin = rutaActual == '/login';
    final bool enOnboarding = rutaActual == '/onboarding';

    if (token == null || token.isEmpty) {
      if (enLogin || enOnboarding) return null;
      return '/onboarding';
    }

    if (enLogin || enOnboarding) {
      final rolRuta = (rol ?? 'empresa').toLowerCase();
      return '/dashboard/$rolRuta';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/onboarding'),
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
          pageBuilder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';

            if (role == 'admin') {
              return const NoTransitionPage(
                key: ValueKey('dashboard-admin'),
                child: AdminScreen(),
              );
            }

            if (role == 'secretaria') {
              return const NoTransitionPage(
                key: ValueKey('dashboard-secretaria'),
                child: SecretariaScreen(),
              );
            }

            return NoTransitionPage(
              key: ValueKey('dashboard-$role'),
              child: DashboardSessionLoader(
                role: role,
                section: 'Inicio',
                showAndroidPrompt: state.uri.queryParameters['showApk'] == '1',
              ),
            );
          },
        ),

        GoRoute(
          path: ':role/:section',
          name: 'dashboard_section',
          pageBuilder: (context, state) {
            final role = state.pathParameters['role'] ?? 'empresa';
            final sectionUrl = state.pathParameters['section'] ?? 'inicio';
            final section = _sectionFromUrl(sectionUrl);

            if (role == 'admin') {
              return const NoTransitionPage(
                key: ValueKey('dashboard-admin'),
                child: AdminScreen(),
              );
            }

            if (role == 'secretaria') {
              return const NoTransitionPage(
                key: ValueKey('dashboard-secretaria'),
                child: SecretariaScreen(),
              );
            }

            return NoTransitionPage(
              key: ValueKey('dashboard-$role'),
              child: DashboardSessionLoader(
                role: role,
                section: section,
                showAndroidPrompt: state.uri.queryParameters['showApk'] == '1',
              ),
            );
          },
        ),
      ],
    ),
  ],
);
