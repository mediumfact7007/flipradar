import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V0.14.1 reserves render space above extra-cost field', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.1+24'));
    final marker = app.indexOf("labelText: t('Zusatzkosten gesamt'");
    expect(marker, greaterThanOrEqualTo(0));
    final before = app.substring((marker - 700).clamp(0, app.length), marker);
    expect(before, contains("ValueKey('v141-extra-cost-top-space')"));
    expect(before, contains('SizedBox(height: 12)'));
  });
}
