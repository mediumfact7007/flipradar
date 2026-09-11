import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FlipRadar v0.8 starts with action-first home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const <SharedMediaFile>[],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
    await tester.pumpWidget(const FlipRadarApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Lohnt sich der Deal?'), findsOneWidget);
    expect(find.text('BARCODE SCANNEN'), findsOneWidget);
  });
}
