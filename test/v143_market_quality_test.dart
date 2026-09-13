import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';

void main() {
  test('removes a severe low accessory-price outlier', () {
    final cleaned = v13CleanMarketValues([24.99, 599, 620, 630, 650, 680]);
    expect(cleaned, isNot(contains(24.99)));
    expect(cleaned.length, 5);
  });

  test('removes a severe high bundle outlier', () {
    final cleaned = v13CleanMarketValues([590, 600, 610, 620, 1300]);
    expect(cleaned, isNot(contains(1300)));
    expect(cleaned, [590, 600, 610, 620]);
  });

  test('keeps a normal compact market spread', () {
    final cleaned = v13CleanMarketValues([450, 500, 550, 600]);
    expect(cleaned, [450, 500, 550, 600]);
  });

  test('small samples discard only an extreme value', () {
    final cleaned = v13CleanMarketValues([20, 600, 620]);
    expect(cleaned, [600, 620]);
  });

  test('invalid market values never enter the calculation', () {
    final cleaned = v13CleanMarketValues([
      double.nan,
      double.infinity,
      -50,
      0,
      500,
      510,
      520,
    ]);
    expect(cleaned, [500, 510, 520]);
  });
}
