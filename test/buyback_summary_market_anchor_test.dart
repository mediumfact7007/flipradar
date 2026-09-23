import 'package:flipradar/buyback.dart';
import 'package:flipradar/buyback_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.parse('2026-09-23T08:00:00Z');
  final offer = BuybackOffer(
    providerId: 'provider',
    providerName: 'Provider',
    productId: 'iphone-15',
    matchedTitle: 'Apple iPhone 15',
    condition: BuybackCondition.likeNew,
    price: 500,
    currency: 'EUR',
    offerUrl: Uri.parse('https://example.com/offer'),
    checkedAt: now.subtract(const Duration(hours: 1)),
    requiresInspection: true,
    matchConfidence: 0.98,
  );

  test('requires a positive private market anchor for a user verdict', () {
    expect(
      buildBuybackComparisonSummary(
        [offer],
        condition: BuybackCondition.likeNew,
        purchasePrice: 400,
        privateMarketValue: 0,
        now: now,
      ),
      isNull,
    );

    expect(
      buildBuybackComparisonSummary(
        [offer],
        condition: BuybackCondition.likeNew,
        purchasePrice: 400,
        privateMarketValue: 650,
        now: now,
      ),
      isNotNull,
    );
  });
}
