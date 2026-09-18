import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('finished search explains when no verified LIVE listings exist', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search('iPhone 15 Pro'),
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
    expect(find.byKey(const ValueKey('v155-live-market-empty')), findsOneWidget);
    expect(find.text('Noch keine verifizierten LIVE-Angebote'), findsOneWidget);
    expect(find.textContaining('Sandbox- oder Referenzwerte'), findsOneWidget);
    monetization.dispose();
  });

  testWidgets('buyback empty state never fabricates a provider price', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search('iPhone 15 Pro'),
          backendBase: 'http://127.0.0.1:1',
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
    final saleFinder = find.byKey(const ValueKey('v13-manual-sale-input'));
    await tester.enterText(saleFinder, '700');
    final commit = find.descendant(of: saleFinder, matching: find.byIcon(Icons.check_rounded));
    expect(commit, findsOneWidget);
    await tester.tap(commit);
    await tester.pump();

    final condition = find.byKey(const ValueKey('v151-buyback-condition'));
    expect(condition, findsOneWidget);
    await tester.ensureVisible(condition);
    await tester.pump();
    await tester.tap(condition);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sehr gut').last);
    await tester.pumpAndSettle();

    final empty = find.byKey(const ValueKey('v156-buyback-empty'));
    expect(empty, findsOneWidget);
    await tester.ensureVisible(empty);
    await tester.pump();
    expect(find.text('Noch kein verifiziertes LIVE-Ankaufangebot'), findsOneWidget);
    expect(find.textContaining('schätzt hier bewusst keinen Ankaufpreis'), findsOneWidget);
    monetization.dispose();
  });
}
