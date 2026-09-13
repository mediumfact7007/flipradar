import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V0.13.4 restores billing without restoring ads', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.13.4+20'));
    expect(pubspec, contains('in_app_purchase: ^3.3.0'));
    expect(pubspec, isNot(contains('google_mobile_ads')));

    expect(app, contains("package:in_app_purchase/in_app_purchase.dart"));
    expect(app, isNot(contains('package:google_mobile_ads')));
    expect(app, contains('SAFE RECOVERY STEP 1'));
    expect(app, contains('_scheduleBillingInit();'));
    expect(app, contains('unawaited(monetization.init());'));
    expect(app, contains('Future<bool> rewardedUnlock() async => false;'));
  });
}
