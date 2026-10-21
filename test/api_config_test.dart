import 'package:flutter_test/flutter_test.dart';
import 'package:trackfile/utils/api_config.dart';

void main() {
  group('ApiConfig.normalize', () {
    test('rechaza valores vacíos', () {
      expect(ApiConfig.normalize(''), isNull);
      expect(ApiConfig.normalize('   '), isNull);
    });

    test('añade https cuando falta el protocolo', () {
      expect(ApiConfig.normalize('example.com'), 'https://example.com');
    });

    test('conserva host y puerto y elimina rutas para la base API', () {
      expect(ApiConfig.normalize('http://localhost:8080/api/v1'), 'http://localhost:8080');
      expect(ApiConfig.normalize('https://api.example.com/path?a=b'), 'https://api.example.com');
    });
  });
}
