import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('V0.10 starts directly with scan and search actions', (tester) async {
    await tester.pumpWidget(const FlipRadarV10App());
    await tester.pumpAndSettle();

    expect(find.text('Lohnt sich das?'), findsOneWidget);
    expect(find.text('JETZT SCANNEN'), findsOneWidget);
    expect(find.text('Produkt, Modell oder EAN suchen'), findsOneWidget);
    expect(find.text('Meine Flips'), findsOneWidget);
  });

  testWidgets('V0.10 manual fallback produces an immediate buy decision', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FastCheckPage(
          english: false,
          initialQuery: 'Testgerät',
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
    await tester.pumpAndSettle();

    expect(find.text('MARKTWERT NOCH NICHT SICHER'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields.evaluate().length, greaterThanOrEqualTo(3));

    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();

    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('148 €'), findsOneWidget);
    expect(find.text('NÄCHSTEN ARTIKEL SCANNEN'), findsOneWidget);
  });
}
