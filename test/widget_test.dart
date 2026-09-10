import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';

void main() {
  testWidgets('FlipRadar starts on home screen', (tester) async {
    await tester.pumpWidget(const FlipRadarApp());
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('1.284 €'), findsOneWidget);
  });
}
