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
  final comparisonTime = now ?? DateTime.now();
  final fresh = results
      .where(
        (result) => result.hasFreshComparableOfferAt(
          comparisonTime,
          maxAge: maxAge,
        ),
      )
      .map((result) => result.offer!);

  // Preserve the caller's freshness window through provider deduplication.
  // Otherwise a deliberately wider/narrower policy could silently fall back
  // to the default 24 h while building the final decision list.
  return distinctBuybackOffers(
    fresh,
    now: comparisonTime,
    maxAge: maxAge,
  );
}
