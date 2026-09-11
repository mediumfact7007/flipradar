import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildCheck({double targetRoi = 35}) {
  return MaterialApp(
    home: CheckPage(
      english: false,
      initialQuery: 'Testgerät 123',
      targetRoi: targetRoi,
      plan: UserPlan.free,
      sources: const [],
      onHistory: (_) {},
      onWatch: (_) {},
      onAddFlip: (_) {},
    ),
  );
}

Future<void> enterManualDeal(
  WidgetTester tester, {
  required String buy,
  required String sell,
}) async {
  await tester.pumpWidget(buildCheck());
  await tester.pumpAndSettle();

  expect(find.text('Noch kein Wiederverkaufswert'), findsOneWidget);
  var fields = find.byType(TextField);
  expect(fields.evaluate().length, greaterThanOrEqualTo(2));
  await tester.enterText(fields.at(1), buy);

  fields = find.byType(TextField);
  if (fields.evaluate().length < 3) {
    await tester.tap(find.text('Verkaufspreis eingeben'));
    await tester.pumpAndSettle();
    fields = find.byType(TextField);
  }
  expect(fields.evaluate().length, greaterThanOrEqualTo(3));
  await tester.enterText(fields.at(2), sell);
  await tester.pump();
}

void main() {
  testWidgets('35% ROI target recommends buy at 100 for 200 sale', (tester) async {
    await enterManualDeal(tester, buy: '100', sell: '200');
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('148 €'), findsOneWidget);
  });

  testWidgets('near-limit deal recommends negotiation and a concrete offer', (tester) async {
    await enterManualDeal(tester, buy: '160', sell: '200');
    expect(find.text('VERHANDELN'), findsOneWidget);
    expect(find.text('Versuch 140 €'), findsOneWidget);
  });
}