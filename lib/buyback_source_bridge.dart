import 'buyback.dart';
import 'source_registry.dart';

/// Lossless bridge between generic market-source payloads and the stricter
/// buyback domain model. Generic [SourceListing] data remains untouched; the
/// comparison UI only receives offers that pass BuybackOffer validation.
class BuybackSourceResult {
  const BuybackSourceResult({required this.listing, this.offer});

  final SourceListing listing;
  final BuybackOffer? offer;

  /// Structural eligibility only. User-facing decisions should use
  /// [hasFreshComparableOfferAt] so stale provider prices are never promoted.
  bool get hasComparableOffer => offer?.isEligibleForComparison == true;

  bool hasFreshComparableOfferAt(
    DateTime now, {
    Duration maxAge = const Duration(hours: 24),
  }) {
    final candidate = offer;
    return candidate != null &&
        candidate.isEligibleForComparison &&
        candidate.isFreshAt(now, maxAge: maxAge);
  }
}

BuybackSourceResult parseBuybackSourceItem(
  Map<String, dynamic> json,
  PriceSource source,
) {
  final listing = SourceListing.fromJson(json, source);
  if (!source.isBuyback) return BuybackSourceResult(listing: listing);

  try {
    final offer = BuybackOffer.fromJson(json);
    return BuybackSourceResult(listing: listing, offer: offer);
  } on FormatException {
    // Keep a generic source result visible, but never promote incomplete or
    // ambiguous buyback metadata into the trusted comparison calculation.
    return BuybackSourceResult(listing: listing);
  } on TypeError {
    return BuybackSourceResult(listing: listing);
  }
}

List<BuybackOffer> comparableBuybackOffers(
  Iterable<BuybackSourceResult> results, {
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  // User-facing comparisons must never silently accept stale provider data.
  // Callers can still inject [now] for deterministic tests/rechecks.
  final comparisonTime = now ?? DateTime.now();
  return results
      .map((result) => result.offer)
      .whereType<BuybackOffer>()
      .where((offer) => offer.isEligibleForComparison)
      .where((offer) => offer.isFreshAt(comparisonTime, maxAge: maxAge))
      .toList(growable: false);
}
