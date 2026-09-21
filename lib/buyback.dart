enum BuybackCondition {
  newSealed,
  likeNew,
  veryGood,
  usedGood,
  acceptable,
  defective,
}

extension BuybackConditionWire on BuybackCondition {
  String get wireValue => switch (this) {
        BuybackCondition.newSealed => 'new_sealed',
        BuybackCondition.likeNew => 'like_new',
        BuybackCondition.veryGood => 'very_good',
        BuybackCondition.usedGood => 'used_good',
        BuybackCondition.acceptable => 'acceptable',
        BuybackCondition.defective => 'defective',
      };

  static BuybackCondition? tryParse(String value) {
    for (final condition in BuybackCondition.values) {
      if (condition.wireValue == value) return condition;
    }
    return null;
  }
}

bool _hasPublicOfferHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      normalized.endsWith('.local') ||
      normalized == '::1') {
    return false;
  }

  if (normalized.contains(':')) {
    // Only globally routable IPv6 destinations belong in user-facing offer links.
    // Block unspecified, loopback, unique-local and link-local ranges.
    return normalized != '::' &&
        !normalized.startsWith('fc') &&
        !normalized.startsWith('fd') &&
        !normalized.startsWith('fe8') &&
        !normalized.startsWith('fe9') &&
        !normalized.startsWith('fea') &&
        !normalized.startsWith('feb');
  }

  final octets = normalized.split('.');
  if (octets.length != 4) return true;
  final ipv4 = octets.map(int.tryParse).toList();
  if (ipv4.any((part) => part == null || part < 0 || part > 255)) return true;

  final a = ipv4[0]!;
  final b = ipv4[1]!;
  final c = ipv4[2]!;
  return !(a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 100 && b >= 64 && b <= 127) ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 0 && c == 0) ||
      (a == 192 && b == 0 && c == 2) ||
      (a == 192 && b == 168) ||
      (a == 198 && (b == 18 || b == 19)) ||
      (a == 198 && b == 51 && c == 100) ||
      (a == 203 && b == 0 && c == 113) ||
      a >= 224);
}

class BuybackOffer {
  const BuybackOffer({
    required this.providerId,
    required this.providerName,
    required this.productId,
    required this.matchedTitle,
    required this.condition,
    required this.price,
    required this.currency,
    required this.offerUrl,
    required this.checkedAt,
    required this.requiresInspection,
    required this.matchConfidence,
    this.conditionUncertain = false,
  });

  static const double maxComparablePriceEur = 10000;

  final String providerId;
  final String providerName;
  final String productId;
  final String matchedTitle;
  final BuybackCondition condition;
  final double price;
  final String currency;
  final Uri offerUrl;
  final DateTime checkedAt;
  final bool requiresInspection;
  final double matchConfidence;
  final bool conditionUncertain;

  bool get isEligibleForComparison {
    final hasPublicOfferHost = _hasPublicOfferHost(offerUrl.host);

    return !conditionUncertain &&
        providerId.trim().isNotEmpty &&
        providerName.trim().isNotEmpty &&
        productId.trim().isNotEmpty &&
        matchedTitle.trim().isNotEmpty &&
        price.isFinite &&
        price > 0 &&
        price <= maxComparablePriceEur &&
        currency == 'EUR' &&
        offerUrl.hasScheme &&
        offerUrl.scheme == 'https' &&
        hasPublicOfferHost &&
        offerUrl.userInfo.isEmpty &&
        matchConfidence.isFinite &&
        matchConfidence >= 0.9 &&
        matchConfidence <= 1;
  }

  bool isFreshAt(
    DateTime now, {
    Duration maxAge = const Duration(hours: 24),
    Duration futureTolerance = const Duration(minutes: 5),
  }) {
    final age = now.toUtc().difference(checkedAt.toUtc());
    return age >= -futureTolerance && age <= maxAge;
  }

  factory BuybackOffer.fromJson(Map<String, dynamic> json) {
    final condition = BuybackConditionWire.tryParse(json['condition'] as String? ?? '');
    if (condition == null) {
      throw const FormatException('Unsupported buyback condition');
    }

    if (json['price_kind'] != 'indicative_buyback') {
      throw const FormatException('Unsupported buyback price kind');
    }

    final price = (json['price'] as num?)?.toDouble();
    final confidence = (json['match_confidence'] as num?)?.toDouble();
    final checkedAt = DateTime.tryParse(json['checked_at'] as String? ?? '');
    final offerUrl = Uri.tryParse(json['offer_url'] as String? ?? '');

    if (price == null || confidence == null || checkedAt == null || offerUrl == null) {
      throw const FormatException('Incomplete buyback offer');
    }

    return BuybackOffer(
      providerId: json['provider_id'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      matchedTitle: json['matched_title'] as String? ?? '',
      condition: condition,
      price: price,
      currency: json['currency'] as String? ?? '',
      offerUrl: offerUrl,
      checkedAt: checkedAt,
      requiresInspection: json['requires_inspection'] as bool? ?? true,
      matchConfidence: confidence,
      conditionUncertain: json['condition_uncertain'] as bool? ?? false,
    );
  }
}

BuybackOffer? bestComparableBuybackOffer(
  Iterable<BuybackOffer> offers, {
  required BuybackCondition condition,
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  BuybackOffer? best;
  for (final offer in offers) {
    if (offer.condition != condition || !offer.isEligibleForComparison) continue;
    if (now != null && !offer.isFreshAt(now, maxAge: maxAge)) continue;
    if (best == null || offer.price > best.price) best = offer;
  }
  return best;
}
