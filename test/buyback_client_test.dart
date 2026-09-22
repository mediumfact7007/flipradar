import 'package:flipradar/buyback.dart';
import 'package:flipradar/buyback_client.dart';
import 'package:flutter_test/flutter_test.dart';

BuybackOffer offer(
  String provider,
  double price, {
  double confidence = 0.98,
  String checkedAt = '2026-09-22T12:00:00Z',
}) =>
    BuybackOffer(
      providerId: provider,
      providerName: provider,
      productId: 'iphone-15-pro-256',
      matchedTitle: 'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.usedGood,
      price: price,
      currency: 'EUR',
      offerUrl: Uri.parse('https://example.com/$provider'),
      checkedAt: DateTime.parse(checkedAt),
      requiresInspection: true,
      matchConfidence: confidence,
    );

void main() {
  test('normalizes whitespace before buyback searches', () {
    expect(
      normalizeBuybackQuery('  Apple\t iPhone 15 Pro\n256 GB  '),
      'Apple iPhone 15 Pro 256 GB',
    );
  });

  test('removes invisible copy-paste characters from buyback searches', () {
    expect(
      normalizeBuybackQuery('Apple\u200BiPhone 15 Pro\u2060 256 GB\uFEFF'),
      'AppleiPhone 15 Pro 256 GB',
    );
  });

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

  test('prefers a more confident provider match over a higher price', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 550, confidence: 0.91),
      offer('rebuy', 510, confidence: 0.99),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 510);
    expect(result.single.matchConfidence, 0.99);
  });

  test('prefers a fresher quote when provider match confidence is equal', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 540, checkedAt: '2026-09-22T10:00:00Z'),
      offer('rebuy', 515, checkedAt: '2026-09-22T12:00:00Z'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 515);
    expect(result.single.checkedAt, DateTime.parse('2026-09-22T12:00:00Z'));
  });

  test('ranks trustworthy provider matches before higher indicative prices', () {
    final result = distinctBuybackOffers([
      offer('high-price', 590, confidence: 0.91),
      offer('trusted', 510, confidence: 0.99),
    ]);

    expect(result.map((item) => item.providerId), ['trusted', 'high-price']);
  });

  test('keeps equally strong providers stable across response order', () {
    final first = distinctBuybackOffers([
      offer('zeta', 510),
      offer('alpha', 510),
    ]);
    final reversed = distinctBuybackOffers([
      offer('alpha', 510),
      offer('zeta', 510),
    ]);

    expect(first.map((item) => item.providerId), ['alpha', 'zeta']);
    expect(reversed.map((item) => item.providerId), ['alpha', 'zeta']);
  });

  test('drops stale and implausibly future-dated quotes when rechecking', () {
    final result = distinctBuybackOffers(
      [
        offer('stale', 600, checkedAt: '2026-09-21T11:59:59Z'),
        offer('fresh', 510, checkedAt: '2026-09-22T12:00:00Z'),
        offer('future', 700, checkedAt: '2026-09-22T12:06:00Z'),
      ],
      now: DateTime.parse('2026-09-22T12:00:00Z'),
    );

    expect(result.map((item) => item.providerId), ['fresh']);
  });
}
