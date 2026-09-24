import 'package:flipwert/main.dart';
import 'package:flipwert/source_registry.dart';
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

  testWidgets('Kleinanzeigen share opens link and asks for manual price', (tester) async {
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
        ),
      ),
    );

    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(field.controller?.text, isEmpty);
    expect(find.byKey(const ValueKey('kleinanzeigen-manual-price')), findsOneWidget);
    expect(find.text('Inserat öffnen'), findsOneWidget);

    monetization.dispose();
  });

  testWidgets('shared text can populate the price without contacting the site', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final input = normalizeV13Search(
      'Nintendo Switch OLED 219 € https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
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
        ),
      ),
    );

    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(field.controller?.text, '219');
    expect(find.byKey(const ValueKey('kleinanzeigen-manual-price')), findsOneWidget);

    monetization.dispose();
  });
}
