import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification/local_notification_helper.dart';

import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Limpieza de configuración vieja guardada en el navegador.
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('api_base_url');
  await LocalNotificationHelper.init();

  runApp(const TrackFileApp());
}

class TrackFileApp extends StatelessWidget {
  const TrackFileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TrackFile',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,

      // Tema general de la aplicación.
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
    );
  }
}