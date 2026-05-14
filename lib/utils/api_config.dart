import '../services/api_link.dart';

class ApiConfig {
  ApiConfig._();

  static final String _apiBaseUrl = getApiLink().replaceAll(
    RegExp(r'/+$'),
    '',
  );

  static String fallbackBaseUrl() => _apiBaseUrl;

  static Future<String> loadBaseUrl() async => _apiBaseUrl;

  static Future<void> saveBaseUrl(String value) async {}

  static Future<void> clearBaseUrl() async {}

  static Uri resolve(String baseUrl, String path) {
    final trimmedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_apiBaseUrl/$trimmedPath');
  }

  static String? normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }
}