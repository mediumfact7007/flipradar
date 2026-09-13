import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V0.14.1 protects the extra-cost floating label from ExpansionTile clipping', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.1+24'));
    expect(app, contains("v0141-cost-label-top-space"));
    expect(app, contains("v0141-extra-costs-input"));

    final spacer = app.indexOf("v0141-cost-label-top-space");
    final field = app.indexOf("v0141-extra-costs-input");
    final label = app.indexOf("labelText: t('Zusatzkosten gesamt', 'Extra costs total')");

    expect(spacer, greaterThanOrEqualTo(0));
    expect(field, greaterThan(spacer));
    expect(label, greaterThan(field));
    expect(field - spacer, lessThan(300));
  });
}
