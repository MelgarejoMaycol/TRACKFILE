// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';

class LocalNotificationHelper {
  static Future<void> init() async {
    return;
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!html.Notification.supported) return;

    if (html.Notification.permission != 'granted') {
      final permission = await html.Notification.requestPermission();

      if (permission != 'granted') {
        return;
      }
    }

    html.Notification(title, body: body, icon: 'assets/logo_circulo.png');
  }
}
