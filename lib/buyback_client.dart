import 'dart:convert';

import 'package:http/http.dart' as http;

import 'buyback.dart';
import 'source_registry.dart';

// Shared/copied listing titles can contain invisible Unicode separators,
// bidirectional formatting marks, or ASCII/C1 control characters that make an
// otherwise exact provider search miss. Treat them as boundaries: removing a
// control outright can join adjacent title words and silently reduce provider
// match quality.
String normalizeBuybackQuery(String query) => query
    .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ')
    .replaceAll(RegExp(r'[\u200B-\u200D\u2060\uFEFF]'), ' ')
    .replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

/// Keeps one trustworthy quote per provider so a noisy adapter cannot make one
/// provider look like multiple independent market signals.
///
/// Invalid or low-confidence quotes are discarded here as a second trust
/// boundary, so future callers cannot accidentally bypass [BuybackOffer]'s
/// comparison rules. When [now] is supplied, stale or implausibly future-dated
/// quotes are rejected here as well. [maxAge] lets callers keep one explicit
/// freshness policy through filtering and provider deduplication.
List<BuybackOffer> distinctBuybackOffers(
  Iterable<BuybackOffer> offers, {
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  final checkedNow = now?.toUtc();
  final byProvider = <String, BuybackOffer>{};
  for (final offer in offers) {
    if (!offer.isEligibleForComparison) continue;
    if (checkedNow != null && !offer.isFreshAt(checkedNow, maxAge: maxAge)) continue;
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
  final providerName = a.providerName.trim().toLowerCase().compareTo(b.providerName.trim().toLowerCase());
  if (providerName != 0) return providerName;
  return a.providerId.trim().toLowerCase().compareTo(b.providerId.trim().toLowerCase());
}

/// Isolated client for FlipRadar's buyback endpoint.
class BuybackClient {
  const BuybackClient({this.backendBase = SourceRegistry.defaultBackend});

  final String backendBase;

  Future<List<BuybackOffer>> search(
    String query, {
    required BuybackCondition condition,
    DateTime? now,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final q = normalizeBuybackQuery(query);
    if (q.isEmpty || q.length > 180 || maxAge.isNegative) return const [];

    final base = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return const [];
    }

    final endpoint = Uri.parse('$base/v1/buyback/search').replace(
      queryParameters: {'q': q, 'condition': condition.wireValue},
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
          if (!offer.isFreshAt(checkedNow, maxAge: maxAge)) continue;
          offers.add(offer);
        } on FormatException {
          // Invalid provider payloads are ignored rather than shown as trusted.
        } on TypeError {
          // Wrongly typed provider payloads are treated as unavailable data.
        }
      }
      return distinctBuybackOffers(
        offers,
        now: checkedNow,
        maxAge: maxAge,
      );
    } catch (_) {
      // Buyback is optional: network/provider failure must never break the
      // primary deal check or the Kleinanzeigen share flow.
      return const [];
    }
  }
}
