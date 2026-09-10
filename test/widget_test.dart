import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FlipRadar v0.7 starts with action-first home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FlipRadarApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Ist das ein guter Deal?'), findsOneWidget);
    expect(find.text('BARCODE SCANNEN'), findsOneWidget);
  });
}
