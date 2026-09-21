import 'package:flipradar/recheck_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecheckDelta delta({double asking = 0, double maxBuy = 0, double profit = 0, double roi = 0}) =>
      RecheckDelta(askingDelta: asking, maxBuyDelta: maxBuy, profitDelta: profit, roiDelta: roi);

  test('small recheck noise stays stable', () {
    final result = delta(asking: -2.99, maxBuy: 2.99, profit: -2.99, roi: 2.99);
    expect(result.directionScore, 0);
    expect(result.stable, isTrue);
    expect(result.improved, isFalse);
    expect(result.worsened, isFalse);
  });

  test('two meaningful positive signals classify as improved', () {
    final result = delta(asking: -3, profit: 3);
    expect(result.directionScore, 2);
    expect(result.improved, isTrue);
    expect(result.stable, isFalse);
  });

  test('two meaningful negative signals classify as worsened', () {
    final result = delta(asking: 3, maxBuy: -3);
    expect(result.directionScore, -2);
    expect(result.worsened, isTrue);
    expect(result.stable, isFalse);
  });

  test('one meaningful signal alone stays stable', () {
    final positive = delta(profit: 3);
    final negative = delta(asking: 3);
    expect(positive.directionScore, 1);
    expect(positive.stable, isTrue);
    expect(positive.improved, isFalse);
    expect(negative.directionScore, -1);
    expect(negative.stable, isTrue);
    expect(negative.worsened, isFalse);
  });

  test('every single signal direction has the expected polarity', () {
    final cases = <RecheckDelta, int>{
      delta(asking: -3): 1,
      delta(asking: 3): -1,
      delta(maxBuy: 3): 1,
      delta(maxBuy: -3): -1,
      delta(profit: 3): 1,
      delta(profit: -3): -1,
      delta(roi: 3): 1,
      delta(roi: -3): -1,
    };
    for (final entry in cases.entries) {
      expect(entry.key.directionScore, entry.value);
      expect(entry.key.stable, isTrue);
      expect(entry.key.improved, isFalse);
      expect(entry.key.worsened, isFalse);
    }
  });

  test('opposing meaningful signals cancel to stable', () {
    final result = delta(asking: -3, maxBuy: -3, profit: 3, roi: -3);
    expect(result.directionScore, 0);
    expect(result.stable, isTrue);
  });

  test('invalid market delta is never reported as stable', () {
    final result = delta(asking: double.nan, profit: 8, roi: double.infinity);
    expect(result.isValid, isFalse);
    expect(result.directionScore, 0);
    expect(result.stable, isFalse);
    expect(result.improved, isFalse);
    expect(result.worsened, isFalse);
  });

  test('compare uses current minus previous values consistently', () {
    final result = RecheckDelta.compare(
      previousAsking: 220,
      currentAsking: 210,
      previousMaxBuy: 250,
      currentMaxBuy: 255,
      previousProfit: 80,
      currentProfit: 86,
      previousRoi: 40,
      currentRoi: 44,
    );
    expect(result.askingDelta, -10);
    expect(result.maxBuyDelta, 5);
    expect(result.profitDelta, 6);
    expect(result.roiDelta, 4);
    expect(result.directionScore, 4);
    expect(result.improved, isTrue);
  });
}
