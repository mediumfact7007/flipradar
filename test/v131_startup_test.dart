import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('V0.13.1 opens even when old prototype preferences are incompatible', (tester) async {
    SharedPreferences.setMockInitialValues({
      'roi_v10': 'not-a-number',
      'min_profit_v12': 'broken',
      'plan_preview_v10': 'broken',
      'tax_mode_v13': 'broken',
      'flips_v10': <String>['{not json}', '{"name":"Legacy"}'],
      'history_v10': <String>['iPhone 15', '', 'iPhone 15'],
    });

    await tester.pumpWidget(const FlipRadarV13App());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Artikel rein.\nEntscheidung raus.'), findsOneWidget);
    expect(find.byKey(const ValueKey('v13-universal-search')), findsOneWidget);
  });
}
