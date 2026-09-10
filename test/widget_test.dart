import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FlipRadar v0.6 starts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_v06': true,
    });
    await tester.pumpWidget(const FlipRadarApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Barcode scannen'), findsOneWidget);
  });
}
