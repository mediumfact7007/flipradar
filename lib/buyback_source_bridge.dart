import 'buyback.dart';
import 'buyback_client.dart';
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
  // Keep the collection path on exactly the same freshness/eligibility rule as
  // single-result UI decisions so future quality gates cannot drift apart.
  final comparisonTime = now ?? DateTime.now();
  final fresh = results
      .where(
        (result) => result.hasFreshComparableOfferAt(
          comparisonTime,
          maxAge: maxAge,
        ),
      )
      .map((result) => result.offer!);

  // Generic source aggregation can contain several matches from the same
  // provider. Apply the same provider-level trust/deduplication rule as the
  // dedicated live client so one noisy provider never looks like multiple
  // independent buyback signals in the decision UI.
  return distinctBuybackOffers(fresh, now: comparisonTime);
}
