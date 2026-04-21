import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontendproyecto/utils/role_router.dart';
import 'package:frontendproyecto/services/document_service.dart';
import 'package:frontendproyecto/services/api_service.dart';
import 'package:frontendproyecto/services/api_link.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('🚀 VERSIÓN: v3.2 - Limpieza de SharedPreferences');
  debugPrint('═══════════════════════════════════════════════════════');
  
  // Limpiar URL vieja de SharedPreferences que podría tener localhost
  final prefs = await SharedPreferences.getInstance();
  final oldUrl = prefs.getString('api_base_url');
  debugPrint('🔴 URL vieja en SharedPreferences: $oldUrl');
  await prefs.remove('api_base_url');
  debugPrint('✅ URL vieja ELIMINADA de SharedPreferences');
  
  // Usar siempre la URL remota de Onrender (sin variables de entorno)
  final String apiBaseUrl = getApiLink();
  debugPrint('🌐 API Base URL configurada: $apiBaseUrl');
  
  // Inicializar AMBOS servicios con la URL correcta
  DocumentService.setBaseUrl(apiBaseUrl);
  ApiService.setBaseUrl(apiBaseUrl);
  
  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('✅ Servicios inicializados correctamente');
  debugPrint('═══════════════════════════════════════════════════════');
  
  runApp(const TrackFileApp());
}

class TrackFileApp extends StatelessWidget {
  const TrackFileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackFile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF091B5A),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFF0C1C58),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C1C58),
          brightness: Brightness.dark,
        ),
      ),
      // Use initialRoute + routes so that named navigation to '/' works
      // while keeping the logic that decides whether to show Onboarding or
      // the real Home inside `_Root`.
      initialRoute: '/',
      routes: {
        '/': (_) => const _Root(),
        LoginScreen.route: (_) => const LoginScreen(),
        OnboardingScreen.route: (_) => const OnboardingScreen(),
      },
    );
  }
}

/// Decide a dónde ir al abrir la app
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final Future<Map<String, dynamic>?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = loadSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const OnboardingScreen();
        }

        final Map<String, dynamic>? userData = snapshot.data;
        if (userData == null) {
          return const OnboardingScreen();
        }

        final Widget? target = screenForRole(userData);
        if (target == null) {
          return const OnboardingScreen();
        }

        return target;
      },
    );
  }
}
