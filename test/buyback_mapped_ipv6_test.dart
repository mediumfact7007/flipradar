import 'package:flipradar/buyback.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> payload(String url) => {
      'provider_id': 'provider',
      'provider_name': 'Provider',
      'product_id': 'phone',
      'matched_title': 'Phone',
      'condition': 'like_new',
      'price': 500,
      'currency': 'EUR',
      'offer_url': url,
      'checked_at': '2026-09-22T10:00:00Z',
      'price_kind': 'indicative_buyback',
      'requires_inspection': true,
      'match_confidence': 0.98,
    };

void main() {
  test('rejects IPv4-mapped IPv6 buyback destinations', () {
    for (final url in [
      'https://[::ffff:127.0.0.1]/offer',
      'https://[::ffff:192.168.1.20]/offer',
      'https://[::ffff:10.0.0.8]/offer',
    ]) {
      expect(
        () => BuybackOffer.fromJson(payload(url)),
        throwsFormatException,
        reason: url,
      );
    }
  });
}
