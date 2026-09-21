class RecheckDelta {
  final double askingDelta;
  final double maxBuyDelta;
  final double profitDelta;
  final double roiDelta;

  const RecheckDelta({
    required this.askingDelta,
    required this.maxBuyDelta,
    required this.profitDelta,
    required this.roiDelta,
  });

  factory RecheckDelta.compare({
    required double previousAsking,
    required double currentAsking,
    required double previousMaxBuy,
    required double currentMaxBuy,
    required double previousProfit,
    required double currentProfit,
    required double previousRoi,
    required double currentRoi,
  }) {
    return RecheckDelta(
      askingDelta: currentAsking - previousAsking,
      maxBuyDelta: currentMaxBuy - previousMaxBuy,
      profitDelta: currentProfit - previousProfit,
      roiDelta: currentRoi - previousRoi,
    );
  }

  /// A recheck comparison is only trustworthy when every input-derived delta
  /// is finite. NaN/Infinity must never be presented as a stable market.
  bool get isValid =>
      askingDelta.isFinite &&
      maxBuyDelta.isFinite &&
      profitDelta.isFinite &&
      roiDelta.isFinite;

  int get directionScore {
    if (!isValid) return 0;
    var score = 0;
    if (askingDelta <= -3) score++;
    if (askingDelta >= 3) score--;
    if (maxBuyDelta >= 3) score++;
    if (maxBuyDelta <= -3) score--;
    if (profitDelta >= 3) score++;
    if (profitDelta <= -3) score--;
    if (roiDelta >= 3) score++;
    if (roiDelta <= -3) score--;
    return score;
  }

  bool get improved => isValid && directionScore >= 2;
  bool get worsened => isValid && directionScore <= -2;
  bool get stable => isValid && !improved && !worsened;
}
