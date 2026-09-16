import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/buyback.dart';

BuybackOffer offer({
  required double price,
  BuybackCondition condition = BuybackCondition.likeNew,
  double confidence = 0.98,
  bool uncertain = false,
}) {
  return BuybackOffer(
    providerId: 'provider-$price',
    providerName: 'Provider',
    productId: 'iphone-15-pro-256',
    matchedTitle: 'Apple iPhone 15 Pro 256 GB',
    condition: condition,
    price: price,
    currency: 'EUR',
    offerUrl: Uri.parse('https://example.com/offer'),
    checkedAt: DateTime.parse('2026-09-16T08:30:00+02:00'),
    requiresInspection: true,
    matchConfidence: confidence,
    conditionUncertain: uncertain,
  );
}

void main() {
  test('condition wire values round-trip', () {
    for (final condition in BuybackCondition.values) {
      expect(BuybackConditionWire.tryParse(condition.wireValue), condition);
    }
  });

  test('selects highest eligible offer for the requested condition', () {
    final best = bestComparableBuybackOffer(
      [offer(price: 590), offer(price: 625), offer(price: 610)],
      condition: BuybackCondition.likeNew,
    );

    expect(best?.price, 625);
  });

  test('does not compare different conditions', () {
    final best = bestComparableBuybackOffer(
      [
        offer(price: 600),
        offer(price: 700, condition: BuybackCondition.usedGood),
      ],
      condition: BuybackCondition.likeNew,
    );

    expect(best?.price, 600);
  });

  test('excludes uncertain and low-confidence matches', () {
    final best = bestComparableBuybackOffer(
      [
        offer(price: 700, uncertain: true),
        offer(price: 680, confidence: 0.75),
        offer(price: 620),
      ],
      condition: BuybackCondition.likeNew,
    );

    expect(best?.price, 620);
  });

  test('parses normalized adapter payload', () {
    final parsed = BuybackOffer.fromJson({
      'provider_id': 'example',
      'provider_name': 'Example',
      'product_id': 'iphone-15-pro-256',
      'matched_title': 'Apple iPhone 15 Pro 256 GB',
      'condition': 'like_new',
      'price': 620,
      'currency': 'EUR',
      'offer_url': 'https://example.com/offer',
      'checked_at': '2026-09-16T08:30:00+02:00',
      'requires_inspection': true,
      'match_confidence': 0.98,
    });

    expect(parsed.condition, BuybackCondition.likeNew);
    expect(parsed.price, 620);
    expect(parsed.isEligibleForComparison, isTrue);
  });
}
