import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/deal_alert.dart';

void main() {
  test('defaults are useful but avoid tiny market noise', () {
    final alert = DealAlertPreference.defaults('flip-1', now: DateTime(2026, 9, 17, 12));
    expect(alert.enabled, isTrue);
    expect(alert.minProfitIncrease, 5);
    expect(alert.minRoiIncrease, 5);
    expect(shouldTriggerDealAlert(preference: alert, previousProfit: 30, currentProfit: 33, previousRoi: 25, currentRoi: 28), isFalse);
  });

  test('material profit or roi improvement triggers enabled alert', () {
    final alert = DealAlertPreference.defaults('flip-1');
    expect(shouldTriggerDealAlert(preference: alert, previousProfit: 30, currentProfit: 35, previousRoi: 25, currentRoi: 26), isTrue);
    expect(shouldTriggerDealAlert(preference: alert, previousProfit: 30, currentProfit: 31, previousRoi: 25, currentRoi: 30), isTrue);
  });

  test('evaluation explains exactly which threshold fired', () {
    final alert = DealAlertPreference.defaults('flip-1');
    final evaluation = evaluateDealAlert(preference: alert, previousProfit: 30, currentProfit: 32, previousRoi: 20, currentRoi: 27);
    expect(evaluation.triggered, isTrue);
    expect(evaluation.profitIncrease, 2);
    expect(evaluation.roiIncrease, 7);
    expect(evaluation.profitThresholdReached, isFalse);
    expect(evaluation.roiThresholdReached, isTrue);
    expect(evaluation.becameProfitable, isFalse);
  });

  test('loss-making recheck stays quiet despite material improvement', () {
    final alert = DealAlertPreference.defaults('flip-1');
    final evaluation = evaluateDealAlert(preference: alert, previousProfit: -30, currentProfit: -10, previousRoi: -25, currentRoi: -10);
    expect(evaluation.profitIncrease, 20);
    expect(evaluation.roiIncrease, 15);
    expect(evaluation.triggered, isFalse);
    expect(evaluation.profitThresholdReached, isFalse);
    expect(evaluation.roiThresholdReached, isFalse);
    expect(evaluation.becameProfitable, isFalse);
  });

  test('crossing into profit triggers even below configured delta thresholds', () {
    final alert = DealAlertPreference.defaults('flip-1');
    final evaluation = evaluateDealAlert(preference: alert, previousProfit: -1, currentProfit: 1, previousRoi: -1, currentRoi: 1);
    expect(evaluation.triggered, isTrue);
    expect(evaluation.becameProfitable, isTrue);
    expect(evaluation.profitThresholdReached, isFalse);
    expect(evaluation.roiThresholdReached, isFalse);
  });

  test('zero thresholds still require a real improvement', () {
    final alert = DealAlertPreference.defaults('flip-1').copyWith(minProfitIncrease: 0, minRoiIncrease: 0);
    final unchanged = evaluateDealAlert(preference: alert, previousProfit: 30, currentProfit: 30, previousRoi: 25, currentRoi: 25);
    expect(unchanged.triggered, isFalse);
    expect(unchanged.profitThresholdReached, isFalse);
    expect(unchanged.roiThresholdReached, isFalse);
    expect(shouldTriggerDealAlert(preference: alert, previousProfit: 30, currentProfit: 30.01, previousRoi: 25, currentRoi: 25), isTrue);
  });

  test('disabled alert never triggers', () {
    final alert = DealAlertPreference.defaults('flip-1').copyWith(enabled: false);
    expect(shouldTriggerDealAlert(preference: alert, previousProfit: 10, currentProfit: 100, previousRoi: 10, currentRoi: 100), isFalse);
  });

  test('preference survives json roundtrip', () {
    final original = DealAlertPreference(flipId: 'flip-7', enabled: true, minProfitIncrease: 8, minRoiIncrease: 12, updatedAt: DateTime.parse('2026-09-17T10:00:00Z').toLocal());
    final restored = DealAlertPreference.fromJson(original.toJson());
    expect(restored, isNotNull);
    expect(restored!.flipId, original.flipId);
    expect(restored.enabled, original.enabled);
    expect(restored.minProfitIncrease, original.minProfitIncrease);
    expect(restored.minRoiIncrease, original.minRoiIncrease);
    expect(restored.updatedAt.toUtc(), original.updatedAt.toUtc());
  });

  test('invalid persisted thresholds are rejected', () {
    expect(DealAlertPreference.fromJson({'flip_id': 'flip-1', 'enabled': true, 'min_profit_increase': -1, 'min_roi_increase': 5, 'updated_at': '2026-09-17T10:00:00Z'}), isNull);
  });
}
