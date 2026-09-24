import 'package:flipwert/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Eigener Starttest. Verhindert zugleich, dass `flutter create` im CI
// die Standard-Vorlage mit `MyApp` erzeugt.
void main() {
  testWidgets('Flipwert startet ohne Fehler', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlipwertV13App());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(FlipwertV13App), findsOneWidget);
  });
}
