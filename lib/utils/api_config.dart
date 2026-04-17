import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  static const String _prefKey = 'api_base_url';
  static const String _compiledBaseUrl = 'https://trackfile-backend.onrender.com';

  static String fallbackBaseUrl() {
    if (_compiledBaseUrl.isNotEmpty) {
      return _compiledBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (io.Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final normalized = _normalize(saved);
      if (normalized != null) {
        return normalized;
      }
    }
    final normalizedFallback = _normalize(fallbackBaseUrl());
    return normalizedFallback ?? 'http://localhost:8080';
  }

  static Future<void> saveBaseUrl(String value) async {
    final normalized = _normalize(value);
    if (normalized == null) {
      throw ArgumentError('Invalid base URL');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
  }

  static Future<void> clearBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  static Uri resolve(String baseUrl, String path) {
    final safeBase = _normalize(baseUrl) ?? _normalize(fallbackBaseUrl()) ?? 'http://localhost:8080';
    final trimmedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(safeBase).resolve(trimmedPath);
  }

  static String? _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }

    if (uri.scheme.isEmpty) {
      uri = Uri.parse('http://$trimmed');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    if (uri.host.isEmpty) {
      return null;
    }

    final buffer = StringBuffer('${uri.scheme}://${uri.host}');

    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }

    final path = uri.path;
    if (path.isNotEmpty && path != '/') {
      buffer.write(path.endsWith('/') ? path.substring(0, path.length - 1) : path);
    }

    return buffer.toString();
  }

  static String? normalize(String value) => _normalize(value);
}
