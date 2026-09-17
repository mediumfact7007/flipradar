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

  const DealAlertPreference({
    required this.flipId,
    required this.enabled,
    required this.minProfitIncrease,
    required this.minRoiIncrease,
    required this.updatedAt,
  });

  factory DealAlertPreference.defaults(String flipId, {DateTime? now}) =>
      DealAlertPreference(
        flipId: flipId,
        enabled: true,
        minProfitIncrease: 5,
        minRoiIncrease: 5,
        updatedAt: now ?? DateTime.now(),
      );

  DealAlertPreference copyWith({
    bool? enabled,
    double? minProfitIncrease,
    double? minRoiIncrease,
    DateTime? updatedAt,
  }) =>
      DealAlertPreference(
        flipId: flipId,
        enabled: enabled ?? this.enabled,
        minProfitIncrease: minProfitIncrease ?? this.minProfitIncrease,
        minRoiIncrease: minRoiIncrease ?? this.minRoiIncrease,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object> toJson() => {
        'flip_id': flipId,
        'enabled': enabled,
        'min_profit_increase': minProfitIncrease,
        'min_roi_increase': minRoiIncrease,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static DealAlertPreference? fromJson(Map<String, dynamic> json) {
    final flipId = json['flip_id'];
    final enabled = json['enabled'];
    final profit = json['min_profit_increase'];
    final roi = json['min_roi_increase'];
    final updated = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    if (flipId is! String || flipId.trim().isEmpty || enabled is! bool ||
        profit is! num || roi is! num || updated == null) return null;
    final p = profit.toDouble();
    final r = roi.toDouble();
    if (!p.isFinite || !r.isFinite || p < 0 || r < 0 || p > 10000 || r > 1000) {
      return null;
    }
    return DealAlertPreference(
      flipId: flipId,
      enabled: enabled,
      minProfitIncrease: p,
      minRoiIncrease: r,
      updatedAt: updated.toLocal(),
    );
  }
}

/// Returns true only for a material improvement over the saved check.
/// A single sufficiently strong profit OR ROI improvement is useful enough to
/// surface; tiny market noise remains silent.
bool shouldTriggerDealAlert({
  required DealAlertPreference preference,
  required double previousProfit,
  required double currentProfit,
  required double previousRoi,
  required double currentRoi,
}) {
  if (!preference.enabled ||
      !previousProfit.isFinite || !currentProfit.isFinite ||
      !previousRoi.isFinite || !currentRoi.isFinite) return false;
  return currentProfit - previousProfit >= preference.minProfitIncrease ||
      currentRoi - previousRoi >= preference.minRoiIncrease;
}
