import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_language.dart';
import 'router/app_router.dart';
import 'services/notifications/notificaciones_realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('api_base_url');
  await AppLanguageController.instance.load();

  runApp(const TrackFileApp());
}

class TrackFileApp extends StatefulWidget {
  const TrackFileApp({super.key});

  @override
  State<TrackFileApp> createState() => _TrackFileAppState();
}

class _TrackFileAppState extends State<TrackFileApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificacionesRealtimeService.checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguageController.instance,
      builder: (context, _, __) {
        return MaterialApp.router(
          title: 'TrackFile',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
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
      },
    );
  }
}
