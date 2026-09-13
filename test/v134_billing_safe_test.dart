import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing remains lazy and isolated from normal app startup', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('in_app_purchase: ^3.3.0'));
    expect(app, contains("package:in_app_purchase/in_app_purchase.dart"));
    expect(app, contains('Billing is initialized lazily by V13Paywall only.'));
    expect(app, contains('unawaited(widget.monetization.init());'));
    expect(app, isNot(contains('  void _scheduleBillingInit() {')));

    final appStateStart = app.indexOf('class _FlipRadarV13AppState');
    final homeStart = app.indexOf('class V13HomePage');
    final startupSlice = app.substring(appStateStart, homeStart);
    expect(startupSlice, isNot(contains('monetization.init()')));
  });
}
