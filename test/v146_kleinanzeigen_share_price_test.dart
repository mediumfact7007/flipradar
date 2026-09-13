import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared listing URL guard accepts only Kleinanzeigen ad URLs', () {
    expect(
      SourceRegistry.sharedListingUrl(
        'Nintendo Switch OLED https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
      )?.host,
      'www.kleinanzeigen.de',
    );
    expect(
      SourceRegistry.sharedListingUrl('https://www.kleinanzeigen.de/s-nintendo-switch-oled/k0'),
      isNull,
    );
    expect(
      SourceRegistry.sharedListingUrl('https://example.com/s-anzeige/nintendo-switch-oled/123'),
      isNull,
    );
  });

  testWidgets('missing Kleinanzeigen share price is loaded into buy field', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final input = normalizeV13Search(
      'Nintendo Switch OLED https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
    );
    expect(input.detectedPrice, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: input,
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: const [],
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
          listingResolver: (_) async => const SharedListingMeta(
            source: 'kleinanzeigen',
            title: 'Nintendo Switch OLED',
            price: 219,
            currency: 'EUR',
            url: 'https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
            kind: 'listing_asking_price',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byKey(const ValueKey('v146-listing-resolving')), findsOneWidget);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(field.controller?.text, '219');
    expect(find.byKey(const ValueKey('v146-listing-resolved')), findsOneWidget);
    expect(find.textContaining('Kleinanzeigen-Link geladen'), findsOneWidget);

    monetization.dispose();
  });

  testWidgets('resolver failure stays transparent and does not invent a price', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final input = normalizeV13Search(
      'Nintendo Switch OLED https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: input,
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: const [],
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
          listingResolver: (_) async => null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(field.controller?.text, isEmpty);
    expect(find.byKey(const ValueKey('v146-listing-failed')), findsOneWidget);

    monetization.dispose();
  });
}
