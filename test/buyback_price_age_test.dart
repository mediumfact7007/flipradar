import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_summary.dart';
import 'package:flipwert/buyback_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows users how recently the buyback price was checked', (tester) async {
    final summary = BuybackComparisonSummary(
      offer: BuybackOffer(
        providerId: 'provider',
        providerName: 'Provider',
        productId: 'phone',
        matchedTitle: 'Phone 256 GB',
        condition: BuybackCondition.likeNew,
        price: 620,
        currency: 'EUR',
        offerUrl: Uri.parse('https://example.com/offer'),
        checkedAt: DateTime.parse('2026-09-23T10:00:00Z'),
        requiresInspection: true,
        matchConfidence: 0.98,
      ),
      purchasePrice: 500,
      privateMarketValue: 680,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BuybackComparisonCard(
      summary: summary,
      now: DateTime.parse('2026-09-23T10:37:00Z'),
    ))));

    final label = tester.widget<Text>(find.byKey(const ValueKey('buyback-checked-at')));
    expect(label.data, contains('vor 37 Min.'));
  });
}
