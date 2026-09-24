import 'package:flipwert/manual_buyback_quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual provider quote is compared without claiming LIVE status', (tester) async {
    ManualBuybackQuote? quote;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManualBuybackQuoteCard(
          purchasePrice: 250,
          privateMarketValue: 390,
          conditionLabel: 'Gebraucht',
          onChanged: (value) => quote = value,
        ),
      ),
    ));

    await tester.enterText(find.byKey(const ValueKey('manual-buyback-price')), '330,00');
    await tester.tap(find.byKey(const ValueKey('manual-buyback-apply')));
    await tester.pump();

    expect(quote?.providerName, 'reBuy');
    expect(quote?.price, 330);
    expect(find.byKey(const ValueKey('manual-buyback-result')), findsOneWidget);
    expect(find.textContaining('Gewinn: 80,00 €'), findsOneWidget);
    expect(find.textContaining('Privatverkauf liegt 60,00 € höher'), findsOneWidget);
    expect(find.textContaining('nicht LIVE geprüft'), findsOneWidget);
  });

  testWidgets('manual quote rejects implausible prices', (tester) async {
    ManualBuybackQuote? quote;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ManualBuybackQuoteCard(
          purchasePrice: 100,
          conditionLabel: 'Wie neu',
          onChanged: (value) => quote = value,
        ),
      ),
    ));

    await tester.enterText(find.byKey(const ValueKey('manual-buyback-price')), '10001');
    await tester.tap(find.byKey(const ValueKey('manual-buyback-apply')));
    await tester.pump();

    expect(quote, isNull);
    expect(find.byKey(const ValueKey('manual-buyback-result')), findsNothing);
  });
}
