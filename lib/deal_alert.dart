/// Local, provider-independent alert preferences for saved Flipwert deals.
///
/// This deliberately contains no push/notification integration yet. It gives
/// the app a stable product model for alert opt-in and meaningful thresholds
/// while keeping external services and permissions out of the core deal flow.
class DealAlertPreference {
  final String flipId;
  final bool enabled;
  final double minProfitIncrease;
  final double minBuybackProfitIncrease;
  final double minRoiIncrease;
  final DateTime updatedAt;

  const DealAlertPreference({required this.flipId, required this.enabled, required this.minProfitIncrease, this.minBuybackProfitIncrease = 5, required this.minRoiIncrease, required this.updatedAt});

  factory DealAlertPreference.defaults(String flipId, {DateTime? now}) => DealAlertPreference(
    flipId: flipId.trim(), enabled: true, minProfitIncrease: 5, minBuybackProfitIncrease: 5, minRoiIncrease: 5, updatedAt: now ?? DateTime.now());

  DealAlertPreference copyWith({bool? enabled, double? minProfitIncrease, double? minBuybackProfitIncrease, double? minRoiIncrease, DateTime? updatedAt}) => DealAlertPreference(
    flipId: flipId, enabled: enabled ?? this.enabled,
    minProfitIncrease: minProfitIncrease ?? this.minProfitIncrease,
    minBuybackProfitIncrease: minBuybackProfitIncrease ?? this.minBuybackProfitIncrease,
    minRoiIncrease: minRoiIncrease ?? this.minRoiIncrease,
    updatedAt: updatedAt ?? this.updatedAt);

  Map<String, Object> toJson() => {
    'flip_id': flipId, 'enabled': enabled, 'min_profit_increase': minProfitIncrease,
    'min_buyback_profit_increase': minBuybackProfitIncrease,
    'min_roi_increase': minRoiIncrease, 'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static DealAlertPreference? fromJson(Map<String, dynamic> json) {
    final flipId = json['flip_id'];
    final enabled = json['enabled'];
    final profit = json['min_profit_increase'];
    final buybackProfit = json['min_buyback_profit_increase'] ?? profit;
    final roi = json['min_roi_increase'];
    final updated = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    if (flipId is! String || flipId.trim().isEmpty || enabled is! bool || profit is! num || buybackProfit is! num || roi is! num || updated == null) return null;
    final normalizedFlipId = flipId.trim();
    final p = profit.toDouble();
    final b = buybackProfit.toDouble();
    final r = roi.toDouble();
    if (!p.isFinite || !b.isFinite || !r.isFinite || p < 0 || b < 0 || r < 0 || p > 10000 || b > 10000 || r > 1000) return null;
    // Persist the canonical saved-deal key. Older/local data can contain
    // harmless surrounding whitespace; keeping it would create a second alert
    // entry that no longer matches the watchlist item during rechecks.
    return DealAlertPreference(flipId: normalizedFlipId, enabled: enabled, minProfitIncrease: p, minBuybackProfitIncrease: b, minRoiIncrease: r, updatedAt: updated.toLocal());
  }
}

class DealAlertEvaluation {
  final bool triggered;
  final double profitIncrease;
  final double roiIncrease;
  final double buybackProfitIncrease;
  final bool profitThresholdReached;
  final bool roiThresholdReached;
  final bool buybackProfitThresholdReached;
  final bool becameProfitable;
  final bool buybackBecameProfitable;

  const DealAlertEvaluation({
    required this.triggered,
    required this.profitIncrease,
    required this.roiIncrease,
    this.buybackProfitIncrease = 0,
    required this.profitThresholdReached,
    required this.roiThresholdReached,
    this.buybackProfitThresholdReached = false,
    this.becameProfitable = false,
    this.buybackBecameProfitable = false,
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
  double? previousBuybackProfit,
  double? currentBuybackProfit,
  bool verifiedBuybackComparison = false,
}) {
  if (!preference.enabled) {
    return const DealAlertEvaluation(triggered: false, profitIncrease: 0, roiIncrease: 0, profitThresholdReached: false, roiThresholdReached: false);
  }
  final privateComparisonValid = previousProfit.isFinite && currentProfit.isFinite && previousRoi.isFinite && currentRoi.isFinite;
  final profitIncrease = privateComparisonValid ? currentProfit - previousProfit : 0.0;
  final roiIncrease = privateComparisonValid ? currentRoi - previousRoi : 0.0;
  // Alerts are actionable deal signals, not generic market-change notices.
  // Require at least one euro of modeled profit for every alert path so a
  // large ROI swing on a near-zero absolute margin cannot create noisy alerts.
  final isActionablyProfitableNow = privateComparisonValid && currentProfit >= 1;
  // Becoming profitable is itself actionable even when the configured delta
  // threshold is larger than the move.
  final becameProfitable = previousProfit <= 0 && isActionablyProfitableNow;
  // Even a zero threshold means "alert on any improvement", not "alert on no
  // change". This keeps rechecks trustworthy for custom low thresholds.
  final profitReached = isActionablyProfitableNow && profitIncrease > 0 && profitIncrease >= preference.minProfitIncrease;
  final roiReached = isActionablyProfitableNow && roiIncrease > 0 && roiIncrease >= preference.minRoiIncrease;
  // A buyback alert is only valid when both snapshots came from the trusted
  // LIVE-provider path. Manual user entries deliberately never enter this
  // calculation, even if their numeric value happens to improve.
  var buybackProfitIncrease = 0.0;
  var buybackBecameProfitable = false;
  var buybackProfitReached = false;
  if (verifiedBuybackComparison &&
      previousBuybackProfit != null &&
      currentBuybackProfit != null &&
      previousBuybackProfit.isFinite &&
      currentBuybackProfit.isFinite) {
    buybackProfitIncrease = currentBuybackProfit - previousBuybackProfit;
    final isBuybackProfitableNow = currentBuybackProfit >= 1;
    buybackBecameProfitable =
        previousBuybackProfit <= 0 && isBuybackProfitableNow;
    buybackProfitReached = isBuybackProfitableNow &&
        buybackProfitIncrease > 0 &&
        buybackProfitIncrease >= preference.minBuybackProfitIncrease;
  }
  return DealAlertEvaluation(
    triggered: becameProfitable || profitReached || roiReached || buybackBecameProfitable || buybackProfitReached,
    profitIncrease: profitIncrease,
    roiIncrease: roiIncrease,
    buybackProfitIncrease: buybackProfitIncrease,
    profitThresholdReached: profitReached,
    roiThresholdReached: roiReached,
    buybackProfitThresholdReached: buybackProfitReached,
    becameProfitable: becameProfitable,
    buybackBecameProfitable: buybackBecameProfitable,
  );
}

/// Compatibility helper for callers that only need yes/no.
bool shouldTriggerDealAlert({
  required DealAlertPreference preference,
  required double previousProfit,
  required double currentProfit,
  required double previousRoi,
  required double currentRoi,
  double? previousBuybackProfit,
  double? currentBuybackProfit,
  bool verifiedBuybackComparison = false,
}) => evaluateDealAlert(
  preference: preference,
  previousProfit: previousProfit,
  currentProfit: currentProfit,
  previousRoi: previousRoi,
  currentRoi: currentRoi,
  previousBuybackProfit: previousBuybackProfit,
  currentBuybackProfit: currentBuybackProfit,
  verifiedBuybackComparison: verifiedBuybackComparison,
).triggered;
