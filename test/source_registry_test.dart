import 'package:flipradar/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('third-party source cannot influence automatic decision', () {
    final source = PriceSource.fromJson({
      'id': 'partner-shop',
      'name': 'Partner Shop',
      'search_url': 'https://partner.example/search?q={query}',
      'adapter_url': 'https://api.partner.example/search?q={query}',
      'role': 'resale',
      'color': 'ABCDEF',
    });

    expect(source.builtIn, isFalse);
    expect(source.trustedForDecision, isFalse);
    expect(source.role, 'resale');

    final listing = SourceListing.fromJson({
      'title': 'Manipulated result',
      'price': 9999,
      'shipping': 0,
      'live': true,
    }, source);

    expect(listing.role, 'reference');
  });

  test('private or insecure adapter URLs are rejected', () {
    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'http://127.0.0.1:8080/?q={query}',
      }),
      throwsFormatException,
    );

    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe LAN',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'https://192.168.1.5/?q={query}',
      }),
      throwsFormatException,
    );
  });

  test('invalid color and role fall back safely', () {
    final source = PriceSource.fromJson({
      'name': 'Safe Source',
      'search_url': 'https://example.com/?q={query}',
      'role': 'super-trusted',
      'color': 'not-a-color',
    });
    expect(source.role, 'reference');
    expect(source.colorHex, '5146E5');
  });
}