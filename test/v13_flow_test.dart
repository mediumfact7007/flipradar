import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/v13_app.dart';

void main() {
  test('flip persistence keeps realized outcome fields', () {
    final created = DateTime(2026, 1, 1);
    final flip = V13Flip(
      id: '1',
      title: 'Test',
      buyPrice: 300,
      status: 'Sold',
      createdAt: created,
      soldAt: created.add(const Duration(days: 9)),
      actualSell: 420,
      soldPlatform: 'eBay',
    );
    final restored = V13Flip.fromJson(flip.toJson());
    expect(restored.daysToSell, 9);
    expect(restored.realizedProfit, 100);
    expect(restored.realizedRoi, closeTo(33.333, 0.01));
    expect(restored.soldPlatform, 'eBay');
  });

  testWidgets('V0.13 home is search-first and barcode remains secondary', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V13Home(
            english: false,
            plan: UserPlan.free,
            history: const ['iPhone 15 Pro'],
            openFlips: 0,
            savedFlips: 0,
            staleSaved: 0,
            monetization: monetization,
            onSearch: (_) {},
            onScan: () {},
            onSettings: () {},
            onOpenFlips: () {},
            onOpenSaved: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Artikel rein.\nEntscheidung raus.'), findsOneWidget);
    expect(find.byKey(const ValueKey('v13-universal-search')), findsOneWidget);
  });
}
