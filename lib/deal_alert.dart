/// Local, provider-independent alert preferences for saved FlipRadar deals.
///
/// This deliberately contains no push/notification integration yet. It gives
/// the app a stable product model for alert opt-in and meaningful thresholds
/// while keeping external services and permissions out of the core deal flow.
class DealAlertPreference {
  final String flipId;
  final bool enabled;
  final double minProfitIncrease;
  final double minRoiIncrease;
  final DateTime updatedAt;

  const DealAlertPreference({required this.flipId, required this.enabled, required this.minProfitIncrease, required this.minRoiIncrease, required this.updatedAt});

  factory DealAlertPreference.defaults(String flipId, {DateTime? now}) => DealAlertPreference(
    flipId: flipId, enabled: true, minProfitIncrease: 5, minRoiIncrease: 5, updatedAt: now ?? DateTime.now());

  DealAlertPreference copyWith({bool? enabled, double? minProfitIncrease, double? minRoiIncrease, DateTime? updatedAt}) => DealAlertPreference(
    flipId: flipId, enabled: enabled ?? this.enabled,
    minProfitIncrease: minProfitIncrease ?? this.minProfitIncrease,
    minRoiIncrease: minRoiIncrease ?? this.minRoiIncrease,
    updatedAt: updatedAt ?? this.updatedAt);

  Map<String, Object> toJson() => {
    'flip_id': flipId, 'enabled': enabled, 'min_profit_increase': minProfitIncrease,
    'min_roi_increase': minRoiIncrease, 'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static DealAlertPreference? fromJson(Map<String, dynamic> json) {
    final flipId = json['flip_id'];
    final enabled = json['enabled'];
    final profit = json['min_profit_increase'];
    final roi = json['min_roi_increase'];
    final updated = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    if (flipId is! String || flipId.trim().isEmpty || enabled is! bool || profit is! num || roi is! num || updated == null) return null;
    final p = profit.toDouble();
    final r = roi.toDouble();
    if (!p.isFinite || !r.isFinite || p < 0 || r < 0 || p > 10000 || r > 1000) return null;
    return DealAlertPreference(flipId: flipId, enabled: enabled, minProfitIncrease: p, minRoiIncrease: r, updatedAt: updated.toLocal());
  }
}

class DealAlertEvaluation {
  final bool triggered;
  final double profitIncrease;
  final double roiIncrease;
  final bool profitThresholdReached;
  final bool roiThresholdReached;
  final bool becameProfitable;

  const DealAlertEvaluation({
    required this.triggered,
    required this.profitIncrease,
    required this.roiIncrease,
    required this.profitThresholdReached,
    required this.roiThresholdReached,
    this.becameProfitable = false,
  });
}

/// Evaluates a recheck and retains both the measured improvement and the exact
/// threshold reason so the UI can explain why an alert fired.
DealAlertEvaluation evaluateDealAlert({
  required DealAlertPreference preference,
  required double previousProfit,
  required double currentProfit,
  required double previousRoi,
  required double currentRoi,
}) {
  if (!preference.enabled || !previousProfit.isFinite || !currentProfit.isFinite || !previousRoi.isFinite || !currentRoi.isFinite) {
    return const DealAlertEvaluation(triggered: false, profitIncrease: 0, roiIncrease: 0, profitThresholdReached: false, roiThresholdReached: false);
  }
  final profitIncrease = currentProfit - previousProfit;
  final roiIncrease = currentRoi - previousRoi;
  // Alerts are actionable deal signals, not generic market-change notices.
  // A recheck that is still loss-making must therefore stay quiet even when
  // the loss became smaller or ROI improved materially.
  final isProfitableNow = currentProfit > 0;
  // Becoming profitable is itself actionable even when the configured delta
  // threshold is larger than the move. This avoids silently missing the most
  // important state change for a watched deal.
  final becameProfitable = previousProfit <= 0 && isProfitableNow;
  // Even a zero threshold means "alert on any improvement", not "alert on no
  // change". This keeps rechecks trustworthy for custom low thresholds.
  final profitReached = isProfitableNow && profitIncrease > 0 && profitIncrease >= preference.minProfitIncrease;
  final roiReached = isProfitableNow && roiIncrease > 0 && roiIncrease >= preference.minRoiIncrease;
  return DealAlertEvaluation(
    triggered: becameProfitable || profitReached || roiReached,
    profitIncrease: profitIncrease,
    roiIncrease: roiIncrease,
    profitThresholdReached: profitReached,
    roiThresholdReached: roiReached,
    becameProfitable: becameProfitable,
  );
}

/// Compatibility helper for callers that only need yes/no.
bool shouldTriggerDealAlert({
  required DealAlertPreference preference,
  required double previousProfit,
  required double currentProfit,
  required double previousRoi,
  required double currentRoi,
}) => evaluateDealAlert(
  preference: preference,
  previousProfit: previousProfit,
  currentProfit: currentProfit,
  previousRoi: previousRoi,
  currentRoi: currentRoi,
).triggered;
