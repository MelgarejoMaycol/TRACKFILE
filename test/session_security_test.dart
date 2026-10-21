import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackfile/utils/session_security.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cerrar sesión limpia identificadores y tokens sin borrar otras preferencias', () async {
    final protectedKeys = [
      'auth_user', 'auth_token', 'token', 'user_id', 'usuario_id',
      'role', 'rol', 'empresa_id', 'conductor_id', 'propietario_id',
    ];
    SharedPreferences.setMockInitialValues({
      for (final key in protectedKeys) key: 'test-sensitive-value',
      'trackfile_language': 'es',
    });

    await clearStoredSession();
    final prefs = await SharedPreferences.getInstance();

    for (final key in protectedKeys) {
      expect(prefs.containsKey(key), isFalse, reason: '$key no debe persistir');
    }
    expect(prefs.getString('trackfile_language'), 'es');
  });
}
