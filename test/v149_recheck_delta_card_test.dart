import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/recheck_delta.dart';
import 'package:flipradar/recheck_delta_card.dart';

void main() {
  testWidgets('shows improved state and deltas', (tester) async {
    final delta = RecheckDelta.compare(
      previousAsking: 220,
      currentAsking: 200,
      previousMaxBuy: 190,
      currentMaxBuy: 205,
      previousProfit: 35,
      currentProfit: 55,
      previousRoi: 18,
      currentRoi: 28,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecheckDeltaCard(english: false, delta: delta),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('v149-recheck-delta')), findsOneWidget);
    expect(find.text('DEAL BESSER GEWORDEN'), findsOneWidget);
    expect(find.text('Preis -20 €'), findsOneWidget);
    expect(find.text('Gewinn +20 €'), findsOneWidget);
  });
}
