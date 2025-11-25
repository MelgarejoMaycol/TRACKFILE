import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    // Guarda un token real después de iniciar sesión; aquí solo verificamos su existencia.
    return prefs.getString('auth_token') != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Si NO hay sesión -> mostrar Onboarding.
        return snapshot.data! ? const _DummyHome() : const OnboardingScreen();
      },
    );
  }
}

/// Pantalla temporal (reemplázala por tu Home real)
class _DummyHome extends StatelessWidget {
  const _DummyHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed(OnboardingScreen.route);
            }
          },
          child: const Text('Cerrar sesión (demo)'),
        ),
      ),
    );
  }
}
