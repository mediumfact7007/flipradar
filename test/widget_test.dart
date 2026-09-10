import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FlipRadar starts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FlipRadarApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Schnellstart'), findsOneWidget);
  });
}
