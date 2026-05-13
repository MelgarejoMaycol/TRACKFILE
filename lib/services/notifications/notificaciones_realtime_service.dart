import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../notificaciones_service.dart';
import 'local_notification_helper.dart';
import 'notificaciones_preferencias_service.dart';

class NotificacionesRealtimeService {
  static Timer? _timer;
  static bool _running = false;

  static Future<void> start() async {
    if (_running) return;

    _running = true;

    await LocalNotificationHelper.init();
    await _checkNotifications(firstLoad: true);

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkNotifications(),
    );
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  static Future<void> _checkNotifications({bool firstLoad = false}) async {
    try {
      final activas = await NotificacionesPreferenciasService.estanActivas();
      if (!activas) return;
      final prefs = await SharedPreferences.getInstance();

      final oldIds =
          prefs.getStringList('trackfile_notificaciones_vistas') ?? <String>[];

      final oldSet = oldIds.toSet();

      final data = await NotificacionesService.listar();

      final nuevas = data.where((item) {
        final id = _getId(item);
        final estado = (item['estado'] ?? '').toString().toUpperCase();

        return id.isNotEmpty && !oldSet.contains(id) && estado == 'ENVIADA';
      }).toList();

      final allIds = data.map(_getId).where((id) => id.isNotEmpty).toSet();

      await prefs.setStringList(
        'trackfile_notificaciones_vistas',
        allIds.toList(),
      );

      if (firstLoad) return;

      nuevas.sort((a, b) {
        final fa = DateTime.tryParse('${a['fechaEnvio'] ?? ''}');
        final fb = DateTime.tryParse('${b['fechaEnvio'] ?? ''}');

        if (fa == null || fb == null) return 0;
        return fa.compareTo(fb);
      });

      for (final item in nuevas) {
        await LocalNotificationHelper.show(
          title: (item['titulo'] ?? 'Nueva notificación').toString(),
          body: (item['mensaje'] ?? 'Tienes una nueva alerta en TrackFile')
              .toString(),
        );
      }
    } catch (_) {
      // Evita romper la app si el token no existe o falla internet.
    }
  }

  static String _getId(Map<String, dynamic> item) {
    return (item['idNotificacion'] ??
            item['id_notificacion'] ??
            item['id'] ??
            '')
        .toString();
  }
}
