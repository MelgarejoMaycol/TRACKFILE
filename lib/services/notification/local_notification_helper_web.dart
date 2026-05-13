// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LocalNotificationHelper {
  static Future<void> init() async {
    if (!html.Notification.supported) return;

    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!html.Notification.supported) return;

    if (html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: '/icons/logoCirculo.png',
      );
    }
  }
}