import 'package:flipradar/recheck_delta.dart';
import 'package:flipradar/recheck_delta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    RecheckDelta delta, {
    bool english = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecheckDeltaCard(english: english, delta: delta),
        ),
      ),
    );
  }

  testWidgets('improved recheck renders positive German state and values', (tester) async {
    await pumpCard(
      tester,
      const RecheckDelta(
        askingDelta: -10,
        maxBuyDelta: 5,
        profitDelta: 8,
        roiDelta: 4,
      ),
    );

    expect(find.text('DEAL BESSER GEWORDEN'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.text('Preis -10 €'), findsOneWidget);
    expect(find.text('MAX +5 €'), findsOneWidget);
    expect(find.text('Gewinn +8 €'), findsOneWidget);
    expect(find.text('ROI +4 %-Pkt'), findsOneWidget);
    expect(find.text('Vergleich mit deinem letzten gespeicherten Check.'), findsOneWidget);
  });

  testWidgets('worsened recheck renders negative English state', (tester) async {
    await pumpCard(
      tester,
      const RecheckDelta(
        askingDelta: 6,
        maxBuyDelta: -4,
        profitDelta: -5,
        roiDelta: -4,
      ),
      english: true,
    );

    expect(find.text('DEAL WORSENED'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    expect(find.text('Price +6 €'), findsOneWidget);
    expect(find.text('Profit -5 €'), findsOneWidget);
    expect(find.text('Compared with your last saved check.'), findsOneWidget);
  });

  testWidgets('small deltas render stable state', (tester) async {
    await pumpCard(
      tester,
      const RecheckDelta(
        askingDelta: -2.99,
        maxBuyDelta: 2.99,
        profitDelta: 0,
        roiDelta: -2.99,
      ),
    );

    expect(find.text('DEAL FAST UNVERÄNDERT'), findsOneWidget);
    expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
  });
}
