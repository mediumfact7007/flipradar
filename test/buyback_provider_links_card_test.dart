import 'package:flipwert/buyback_provider_links_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider fallback uses only official HTTPS destinations', () {
    expect(buybackProviderDestinations.map((item) => item.id), ['rebuy', 'zoxs', 'clevertronic']);
    for (final provider in buybackProviderDestinations) {
      expect(provider.url.scheme, 'https');
      expect(provider.url.host, isNotEmpty);
    }
  });

  testWidgets('opens official provider and copies the current product query', (tester) async {
    Uri? opened;
    String? copied;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BuybackProviderLinksCard(
          query: '  Apple   iPhone 15 Pro 256 GB  ',
          launcher: (uri) async {
            opened = uri;
            return true;
          },
          copyQuery: (query) async => copied = query,
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('buyback-provider-links-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buyback-provider-zoxs')));
    await tester.pump();

    expect(opened, Uri.parse('https://www.zoxs.de/'));
    expect(copied, 'Apple iPhone 15 Pro 256 GB');
    expect(find.textContaining('Suchbegriff kopiert'), findsOneWidget);
  });
}
