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

  bool get isEligibleForComparison =>
      !conditionUncertain &&
      providerId.trim().isNotEmpty &&
      providerName.trim().isNotEmpty &&
      matchedTitle.trim().isNotEmpty &&
      price >= 0 &&
      currency == 'EUR' &&
      offerUrl.hasScheme &&
      offerUrl.scheme == 'https' &&
      matchConfidence >= 0.9 &&
      matchConfidence <= 1;

  factory BuybackOffer.fromJson(Map<String, dynamic> json) {
    final condition = BuybackConditionWire.tryParse(json['condition'] as String? ?? '');
    if (condition == null) {
      throw const FormatException('Unsupported buyback condition');
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
}) {
  BuybackOffer? best;
  for (final offer in offers) {
    if (offer.condition != condition || !offer.isEligibleForComparison) continue;
    if (best == null || offer.price > best.price) best = offer;
  }
  return best;
}
