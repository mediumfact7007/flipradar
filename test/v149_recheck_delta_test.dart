import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/recheck_delta.dart';

void main() {
  test('classifies a clearly improved saved deal', () {
    final delta = RecheckDelta.compare(
      previousAsking: 220,
      currentAsking: 200,
      previousMaxBuy: 190,
      currentMaxBuy: 205,
      previousProfit: 35,
      currentProfit: 55,
      previousRoi: 18,
      currentRoi: 28,
    );

    expect(delta.improved, isTrue);
    expect(delta.worsened, isFalse);
    expect(delta.askingDelta, -20);
    expect(delta.profitDelta, 20);
  });

  test('classifies a clearly worsened saved deal', () {
    final delta = RecheckDelta.compare(
      previousAsking: 180,
      currentAsking: 195,
      previousMaxBuy: 205,
      currentMaxBuy: 190,
      previousProfit: 60,
      currentProfit: 35,
      previousRoi: 34,
      currentRoi: 19,
    );

    expect(delta.worsened, isTrue);
    expect(delta.improved, isFalse);
  });

  test('ignores tiny market noise', () {
    final delta = RecheckDelta.compare(
      previousAsking: 200,
      currentAsking: 199,
      previousMaxBuy: 210,
      currentMaxBuy: 211,
      previousProfit: 50,
      currentProfit: 51,
      previousRoi: 25,
      currentRoi: 26,
    );

    expect(delta.stable, isTrue);
    expect(delta.directionScore, 0);
  });
}
