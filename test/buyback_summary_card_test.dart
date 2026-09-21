import 'package:flipradar/buyback.dart';
import 'package:flipradar/buyback_summary.dart';
import 'package:flipradar/buyback_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BuybackComparisonSummary summaryWithUrl(Uri url) {
  return BuybackComparisonSummary(
    offer: BuybackOffer(
      providerId: 'provider',
      providerName: 'Provider',
      productId: 'iphone-15-pro-256',
      matchedTitle: 'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.likeNew,
      price: 620,
      currency: 'EUR',
      offerUrl: url,
      checkedAt: DateTime.parse('2026-09-21T12:00:00Z'),
      requiresInspection: true,
      matchConfidence: 0.98,
    ),
    purchasePrice: 500,
    privateMarketValue: 680,
  );
}

void main() {
  testWidgets('buyback action stays disabled for non-public offer targets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://127.0.0.1/offer')),
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buyback-open-offer')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Angebotslink nicht verfügbar'), findsOneWidget);
  });

  testWidgets('buyback action stays enabled for a trusted public offer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buyback-open-offer')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('recommendation states the concrete private-sale profit advantage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    expect(find.text('Privatverkauf: 60,00 € mehr Gewinn'), findsOneWidget);
  });
}
