import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sold dialog accepts German thousands format', (tester) async {
    FlipItem? updated;
    final item = FlipItem(
      id: '1',
      name: 'Testgerät',
      buy: 700,
      sell: 1200,
      costs: 25,
      status: 'Listed',
      source: 'Test',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlipsPage(
            english: false,
            plan: UserPlan.pro,
            flips: [item],
            onUpdate: (value) => updated = value,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Verkauft'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1.299,99');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.status, 'Sold');
    expect(updated!.sell, closeTo(1299.99, 0.001));
  });
}
