import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../notificaciones_service.dart';
import 'local_notification_helper.dart';
import 'notificaciones_preferencias_service.dart';

class NotificacionesRealtimeService {
  static Timer? _timer;
  static bool _running = false;

  static Future<void> Function()? onNotificationsChanged;

  static Future<void> start({Future<void> Function()? onChanged}) async {
    if (onChanged != null) {
      onNotificationsChanged = onChanged;
    }

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
    onNotificationsChanged = null;
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
        final estado = (item['estado'] ?? item['status'] ?? '')
            .toString()
            .toUpperCase();
        final leida = item['leida'] == true;

        return id.isNotEmpty &&
            !oldSet.contains(id) &&
            !leida &&
            estado != 'LEIDA' &&
            estado != 'LEÍDA' &&
            estado != 'READ';
      }).toList();

      final allIds = data.map(_getId).where((id) => id.isNotEmpty).toSet();

      if (nuevas.isEmpty) {
        if (firstLoad) {
          await prefs.setStringList(
            'trackfile_notificaciones_vistas',
            allIds.toList(),
          );
        }

        await onNotificationsChanged?.call();
        return;
      }

      await prefs.setStringList(
        'trackfile_notificaciones_vistas',
        allIds.toList(),
      );

      await onNotificationsChanged?.call();

      final notificacionesParaMostrar = firstLoad && oldSet.isEmpty
          ? nuevas.where(_esReciente).toList()
          : nuevas;

      notificacionesParaMostrar.sort((a, b) {
        final fa = DateTime.tryParse('${a['fechaEnvio'] ?? ''}');
        final fb = DateTime.tryParse('${b['fechaEnvio'] ?? ''}');

        if (fa == null || fb == null) return 0;
        return fa.compareTo(fb);
      });

      for (final item in notificacionesParaMostrar) {
        await LocalNotificationHelper.show(
          title: (item['titulo'] ?? 'Nueva notificación').toString(),
          body: (item['mensaje'] ?? 'Tienes una nueva alerta en TrackFile')
              .toString(),
        );
      }
    } catch (_) {
      // Evita romper la sesión si falla una consulta de notificaciones.
    }
  }

  static String _getId(Map<String, dynamic> item) {
    return (item['idNotificacion'] ??
            item['id_notificacion'] ??
            item['id'] ??
            '')
        .toString();
  }

  static bool _esReciente(Map<String, dynamic> item) {
    final fecha = DateTime.tryParse('${item['fechaEnvio'] ?? ''}');
    if (fecha == null) return true;

    return DateTime.now().difference(fecha.toLocal()).inHours <= 24;
  }
}
