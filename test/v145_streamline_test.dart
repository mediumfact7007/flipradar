import 'dart:io';

import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share listener stays behind first frame and source failures are retryable', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.5+28'));
    expect(app, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(app, contains('Platform.isAndroid || Platform.isIOS'));
    expect(app, contains('if (shareSub != null) return;'));
    expect(app, contains('final Set<String> failed = {};'));
    expect(app, contains('void _retryFailed()'));
    expect(app, contains("ValueKey('v145-retry-sources')"));

    final shellStart = app.indexOf('class _V13ShellState');
    final listenStart = app.indexOf('void _listenShares()', shellStart);
    final initStart = app.indexOf('void initState()', shellStart);
    final initEnd = app.indexOf('void _listenShares()', initStart);
    final initSlice = app.substring(initStart, initEnd);
    expect(initSlice, contains('addPostFrameCallback'));
    expect(initSlice, contains('_listenShares()'));
    expect(listenStart, greaterThan(initStart));
  });

  testWidgets('home keeps raw pasted listing data, clears quickly and opens flips', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    String? submitted;
    var openedFlips = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13Home(
          english: false,
          plan: UserPlan.pro,
          history: const [],
          openFlips: 2,
          monetization: monetization,
          onSearch: (value) => submitted = value,
          onScan: () {},
          onSettings: () {},
          onOpenFlips: () => openedFlips = true,
        ),
      ),
    ));

    const raw = 'Samsung Galaxy S25\n499 €\nhttps://www.ebay.de/itm/123456789';
    final field = find.byKey(const ValueKey('v13-universal-search'));
    await tester.enterText(field, raw);
    await tester.pump();

    expect(find.byKey(const ValueKey('v145-clear-search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v13-check-button')));
    await tester.pump();
    expect(submitted, raw);

    await tester.tap(find.byKey(const ValueKey('v145-open-flips')));
    await tester.pump();
    expect(openedFlips, isTrue);

    await tester.tap(find.byKey(const ValueKey('v145-clear-search')));
    await tester.pump();
    expect(find.text(raw), findsNothing);

    monetization.dispose();
  });
}
