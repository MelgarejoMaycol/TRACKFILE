// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trackfile/main.dart'; // asegúrate que coincide con el "name:" de pubspec.yaml

void main() {
  setUp(() {
    // Sin sesión iniciada para que muestre el Onboarding
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Muestra el onboarding y navega a Login', (WidgetTester tester) async {
    await tester.pumpWidget(const TrackFileApp());

    // Espera a que el FutureBuilder y las animaciones finalicen
    await tester.pumpAndSettle();

    // Debe verse el botón "ÚNETE" del onboarding
    final joinFinder = find.text('ÚNETE');
    expect(joinFinder, findsOneWidget);

    // Garantiza que el botón esté visible para la interacción en pantallas pequeñas
    await tester.ensureVisible(joinFinder);

    // Tocar y navegar a la pantalla de login
    await tester.tap(joinFinder);
    await tester.pumpAndSettle();

    // Verifica que estás en Login
    expect(find.text('INICIA SESIÓN'), findsOneWidget);
  });
}
