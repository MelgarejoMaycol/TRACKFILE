import 'package:flutter/foundation.dart';
import '../services/api_link.dart';

class ApiConfig {
  ApiConfig._();

  // URL de la API traida de api_link.dart desde la función getApiLink()
  static final String _apiBaseUrl = getApiLink();

  static String fallbackBaseUrl() {
    // SIEMPRE devolver la URL remota
    return _apiBaseUrl;
  }

  static Future<String> loadBaseUrl() async {
    // SIEMPRE usar la URL remota compilada
    return _apiBaseUrl;
  }

  static Future<void> saveBaseUrl(String value) async {
    // Ya no es necesario guardar en SharedPreferences
    // SIEMPRE usamos la URL remota compilada
    debugPrint('ℹ️ saveBaseUrl() no hace nada - usando URL remota: $_apiBaseUrl');
  }

  static Future<void> clearBaseUrl() async {
    // Ya no es necesario
    debugPrint('ℹ️ clearBaseUrl() no hace nada - usando URL remota: $_apiBaseUrl');
  }

  static Uri resolve(String baseUrl, String path) {
    // SIEMPRE usar la URL remota compilada, ignorar parámetro baseUrl
    final safeBase = _apiBaseUrl;
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
