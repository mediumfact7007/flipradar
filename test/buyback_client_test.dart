import 'package:flipradar/buyback.dart';
import 'package:flipradar/buyback_client.dart';
import 'package:flutter_test/flutter_test.dart';

BuybackOffer offer(String provider, double price) => BuybackOffer(
      providerId: provider,
      providerName: provider,
      productId: 'iphone-15-pro-256',
      matchedTitle: 'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.usedGood,
      price: price,
      currency: 'EUR',
      offerUrl: Uri.parse('https://example.com/$provider'),
      checkedAt: DateTime.parse('2026-09-22T12:00:00Z'),
      requiresInspection: true,
      matchConfidence: 0.98,
    );

void main() {
  test('keeps only the best quote from each buyback provider', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 510),
      offer('rebuy', 525),
      offer('wirkaufens', 520),
    ]);

    expect(result.map((item) => item.providerId), ['rebuy', 'wirkaufens']);
    expect(result.map((item) => item.price), [525, 520]);
  });

  test('normalizes provider ids before deduplication', () {
    final result = distinctBuybackOffers([
      offer(' Rebuy ', 500),
      offer('rebuy', 515),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 515);
  });
}
