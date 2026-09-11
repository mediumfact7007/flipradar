import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const <SharedMediaFile>[],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
  });

  test('money input supports German and English formats safely', () {
    expect(parseMoneyInput('1.299,99 €'), closeTo(1299.99, 0.001));
    expect(parseMoneyInput('1,299.99'), closeTo(1299.99, 0.001));
    expect(parseMoneyInput('49,90'), closeTo(49.90, 0.001));
    expect(parseMoneyInput('1.299'), closeTo(1299, 0.001));
    expect(parseMoneyInput('1.234.567,89'), closeTo(1234567.89, 0.001));
    expect(parseMoneyInput('-20'), 0);
    expect(parseMoneyInput('abc'), 0);
  });

  test('shared marketplace text extracts a useful product query', () {
    expect(
      extractSharedQuery(
        'Gerade bei #Kleinanzeigen gefunden. Wie findest du das?\n'
        'https://www.kleinanzeigen.de/s-anzeige/apple-iphone-15-pro-256gb/1234567890-173-1234',
      ),
      'apple iphone 15 pro 256gb',
    );
    expect(
      extractSharedQuery(
        'Apple iPhone 15 Pro 256GB 850 € https://www.ebay.de/itm/123456789',
      ),
      'Apple iPhone 15 Pro 256GB',
    );
    expect(
      extractSharedQuery('https://www.ebay.de/sch/i.html?_nkw=PlayStation+5+Slim'),
      'PlayStation 5 Slim',
    );
  });

  testWidgets('FlipRadar final starts with action-first home', (tester) async {
    await tester.pumpWidget(const FlipRadarFinalApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Lohnt sich der Deal?'), findsOneWidget);
    expect(find.text('BARCODE SCANNEN'), findsOneWidget);
  });

  testWidgets('changing the item clears an old manual deal decision', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FinalCheckPage(
          english: false,
          initialQuery: '',
          targetRoi: 35,
          plan: UserPlan.free,
          sources: const [],
          onHistory: (_) {},
          onWatch: (_) {},
          onAddFlip: (_) {},
          onRemoveFlip: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'iPhone 15');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine automatischen Wiederverkaufsdaten'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.enterText(find.byType(TextField).at(2), '200');
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'PlayStation 5');
    await tester.pump();
    expect(find.text('KAUFEN'), findsNothing);
    expect(find.text('Artikel suchen → Preis eingeben → Entscheidung.'), findsOneWidget);
  });
}
