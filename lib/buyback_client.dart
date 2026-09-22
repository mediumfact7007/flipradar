import 'dart:convert';

import 'package:http/http.dart' as http;

import 'buyback.dart';
import 'source_registry.dart';

// Shared/copied listing titles can contain invisible Unicode separators that
// make an otherwise exact provider search miss. Remove those before sending it.
String normalizeBuybackQuery(String query) => query
    .replaceAll(RegExp(r'[\u200B-\u200D\u2060\uFEFF]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

/// Keeps one trustworthy quote per provider so a noisy adapter cannot make one
/// provider look like multiple independent market signals.
///
/// Invalid or low-confidence quotes are discarded here as a second trust
/// boundary, so future callers cannot accidentally bypass [BuybackOffer]'s
/// comparison rules. When [now] is supplied, stale or implausibly future-dated
/// quotes are rejected here as well. When a provider returns multiple matches,
/// prefer the most confident match, then the freshest quote, and only then the
/// higher price. Across providers, keep that same trust-first ordering so a
/// less certain match is never shown ahead of a more reliable quote merely
/// because its indicative price is higher.
List<BuybackOffer> distinctBuybackOffers(
  Iterable<BuybackOffer> offers, {
  DateTime? now,
}) {
  final checkedNow = now?.toUtc();
  final byProvider = <String, BuybackOffer>{};
  for (final offer in offers) {
    if (!offer.isEligibleForComparison) continue;
    if (checkedNow != null && !offer.isFreshAt(checkedNow)) continue;
    final key = offer.providerId.trim().toLowerCase();
    if (key.isEmpty) continue;
    final current = byProvider[key];
    if (current == null || _isBetterProviderQuote(offer, current)) {
      byProvider[key] = offer;
    }
  }
  final result = byProvider.values.toList()..sort(_compareProviderQuotes);
  return List.unmodifiable(result);
}

bool _isBetterProviderQuote(BuybackOffer candidate, BuybackOffer current) =>
    _compareProviderQuotes(candidate, current) < 0;

int _compareProviderQuotes(BuybackOffer a, BuybackOffer b) {
  final confidence = b.matchConfidence.compareTo(a.matchConfidence);
  if (confidence != 0) return confidence;
  final freshness = b.checkedAt.toUtc().compareTo(a.checkedAt.toUtc());
  if (freshness != 0) return freshness;
  final price = b.price.compareTo(a.price);
  if (price != 0) return price;

  // Keep equally strong provider results stable across backend response order.
  // A deterministic list avoids cards apparently jumping between rechecks when
  // nothing about the market actually changed.
  final providerName = a.providerName
      .trim()
      .toLowerCase()
      .compareTo(b.providerName.trim().toLowerCase());
  if (providerName != 0) return providerName;
  return a.providerId
      .trim()
      .toLowerCase()
      .compareTo(b.providerId.trim().toLowerCase());
}

/// Isolated client for FlipRadar's buyback endpoint.
///
/// It deliberately does not feed buyback prices into the normal resale-market
/// decision pipeline. Callers only receive offers that pass the strict
/// [BuybackOffer] validation and freshness checks.
class BuybackClient {
  const BuybackClient({this.backendBase = SourceRegistry.defaultBackend});

  final String backendBase;

  Future<List<BuybackOffer>> search(
    String query, {
    required BuybackCondition condition,
    DateTime? now,
  }) async {
    final q = normalizeBuybackQuery(query);
    if (q.isEmpty || q.length > 180) return const [];

    final base = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return const [];
    }

    final endpoint = Uri.parse('$base/v1/buyback/search').replace(
      queryParameters: {
        'q': q,
        'condition': condition.wireValue,
      },
    );

    try {
      final response = await http.get(endpoint).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      if (response.bodyBytes.length > 512 * 1024) return const [];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const [];
      final rawItems = decoded['items'];
      if (rawItems is! List) return const [];

      final checkedNow = (now ?? DateTime.now()).toUtc();
      final offers = <BuybackOffer>[];
      for (final item in rawItems.take(50)) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final offer = BuybackOffer.fromJson(item);
          if (offer.condition != condition || !offer.isEligibleForComparison) continue;
          if (!offer.isFreshAt(checkedNow)) continue;
          offers.add(offer);
        } on FormatException {
          // Invalid provider payloads are ignored rather than shown as trusted.
        } on TypeError {
          // Wrongly typed provider payloads are treated as unavailable data.
        }
      }
      return distinctBuybackOffers(offers, now: checkedNow);
    } catch (_) {
      // Buyback is optional: network/provider failure must never break the
      // primary deal check or the Kleinanzeigen share flow.
      return const [];
    }
  }
}
