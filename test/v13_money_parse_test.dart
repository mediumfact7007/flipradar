import 'package:flipwert/main.dart';
import 'package:flutter_test/flutter_test.dart';

// Ersetzt die Abdeckung aus dem entfernten library_flow_test:
// Preise im deutschen Format müssen korrekt erkannt werden,
// z. B. im Verkaufs-Dialog.
void main() {
  test('deutsches Format mit Tausenderpunkt und Komma', () {
    expect(v13Money('1.299,99'), closeTo(1299.99, 0.001));
    expect(v13Money('1.000,00'), closeTo(1000, 0.001));
    expect(v13Money('1.299,99 €'), closeTo(1299.99, 0.001));
  });

  test('nur Tausenderpunkt oder nur Dezimalkomma', () {
    expect(v13Money('1.299'), closeTo(1299, 0.001));
    expect(v13Money('12,5'), closeTo(12.5, 0.001));
  });

  test('englisches Format', () {
    expect(v13Money('1,299.99'), closeTo(1299.99, 0.001));
  });

  test('ungültige Eingaben ergeben 0', () {
    expect(v13Money(''), 0);
    expect(v13Money('abc'), 0);
    expect(v13Money('-5'), 0);
  });
}
