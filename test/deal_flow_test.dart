import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildCheck({double targetRoi = 35}) {
  return MaterialApp(
    home: FinalCheckPage(
      english: false,
      initialQuery: 'Testgerät 123',
      targetRoi: targetRoi,
      plan: UserPlan.free,
      sources: const [],
      onHistory: (_) {},
      onWatch: (_) {},
      onAddFlip: (_) {},
      onRemoveFlip: (_) {},
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

  expect(find.text('Noch keine automatischen Wiederverkaufsdaten'), findsOneWidget);
  final fields = find.byType(TextField);
  expect(fields.evaluate().length, greaterThanOrEqualTo(3));
  await tester.enterText(fields.at(1), buy);
  await tester.enterText(fields.at(2), sell);
  await tester.pump();
}

void main() {
  testWidgets('active final flow recommends buy at target ROI', (tester) async {
    await enterManualDeal(tester, buy: '100', sell: '200');
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('148 €'), findsOneWidget);
  });

  testWidgets('active final flow recommends a concrete negotiation', (tester) async {
    await enterManualDeal(tester, buy: '160', sell: '200');
    expect(find.text('VERHANDELN'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Versuch 140 €'), findsOneWidget);
  });

  testWidgets('German thousands input is accepted in active deal flow', (tester) async {
    await enterManualDeal(tester, buy: '1.000,00', sell: '2.000,00');
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('1481 €'), findsOneWidget);
  });
}
