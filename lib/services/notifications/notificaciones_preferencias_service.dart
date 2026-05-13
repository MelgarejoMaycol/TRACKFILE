import 'package:shared_preferences/shared_preferences.dart';

class NotificacionesPreferenciasService {
  static const String _key = 'trackfile_notificaciones_activas';

  static Future<bool> estanActivas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> guardar(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}