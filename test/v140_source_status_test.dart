import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/source_registry.dart';
import 'package:flipradar/source_status.dart';

void main() {
  test('parses configured and browser-only source status', () {
    final status = MarketBackendStatus.fromJson({
      'sources': {
        'ebay_de': {
          'configured': true,
          'mode': 'official_api',
          'estimate': 'used_fixed_price_active_listings',
        },
        'amazon_de': {
          'configured': false,
          'mode': 'keepa',
          'estimate': 'retail_reference',
        },
        'kleinanzeigen': {
          'configured': false,
          'mode': 'official_search_link',
        },
      },
    });

    expect(status.reachable, isTrue);
    expect(status.isLive('ebay_de'), isTrue);
    expect(status.isLive('amazon_de'), isFalse);
    expect(status.sources['kleinanzeigen']?.mode, 'official_search_link');
  });

  test('derives status endpoint from the configured FlipRadar adapter', () {
    final sources = SourceRegistry.builtIns();
    final endpoint = MarketStatusClient.endpointFor(sources);

    expect(endpoint, isNotNull);
    expect(endpoint!.scheme, 'https');
    expect(endpoint.host, 'flipradar-api-production-ec00.up.railway.app');
    expect(endpoint.path, '/v1/status');
    expect(endpoint.query, isEmpty);
  });
}
