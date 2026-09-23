import 'buyback.dart';

/// User-facing comparison data for a fast exit via a buyback provider.
///
/// This stays independent from widgets and provider adapters so the same
/// trusted calculation can later power the deal result, watchlist rechecks,
/// and Pro alerts without duplicating margin logic.
class BuybackComparisonSummary {
  const BuybackComparisonSummary({
    required this.offer,
    required this.purchasePrice,
    required this.privateMarketValue,
  });

  final BuybackOffer offer;
  final double purchasePrice;
  final double privateMarketValue;

  double get instantMargin => offer.price - purchasePrice;

  double get privateMargin => privateMarketValue - purchasePrice;

  double get instantRoi =>
      purchasePrice > 0 ? (instantMargin / purchasePrice) * 100 : 0;

  double get privateRoi =>
      purchasePrice > 0 ? (privateMargin / purchasePrice) * 100 : 0;

  /// How much gross upside the user gives up for the faster, simpler exit.
  double get convenienceGap => privateMarketValue - offer.price;

  bool get instantExitProfitable => instantMargin > 0;
}

BuybackComparisonSummary? buildBuybackComparisonSummary(
  Iterable<BuybackOffer> offers, {
  required BuybackCondition condition,
  required double purchasePrice,
  required double privateMarketValue,
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  if (!purchasePrice.isFinite || purchasePrice < 0) return null;
  // A zero/negative private value means FlipRadar has no usable market anchor.
  // Never turn that absence into a misleading "instant buyback wins" verdict.
  if (!privateMarketValue.isFinite || privateMarketValue <= 0) return null;

  // User-facing comparisons must never silently accept stale provider data.
  // Callers can still inject [now] for deterministic tests/rechecks.
  final comparisonTime = now ?? DateTime.now();
  final best = bestComparableBuybackOffer(
    offers,
    condition: condition,
    now: comparisonTime,
    maxAge: maxAge,
  );
  if (best == null) return null;

  return BuybackComparisonSummary(
    offer: best,
    purchasePrice: purchasePrice,
    privateMarketValue: privateMarketValue,
  );
}
