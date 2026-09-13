from pathlib import Path

app_path = Path('lib/v13_app.dart')
app = app_path.read_text()

old_call = """          _V13MarketStrip(
            english: widget.english,
            expectedSale: expectedSale,
            activeMedian: activeMedian,
            count: resaleValues.length,
            confidence: confidence,
            pending: pending.length,
            personal: personal,
            isPro: widget.plan != UserPlan.free,
          ),
          const SizedBox(height: 10),
"""
new_call = """          _V13MarketStrip(
            english: widget.english,
            expectedSale: expectedSale,
            activeMedian: activeMedian,
            count: resaleValues.length,
            confidence: confidence,
            pending: pending.length,
            personal: personal,
            isPro: widget.plan != UserPlan.free,
          ),
          const SizedBox(height: 8),
          _V14ConfidenceCard(english: widget.english, confidence: marketConfidence),
          const SizedBox(height: 10),
"""
if old_call in app:
    app = app.replace(old_call, new_call, 1)
elif '_V14ConfidenceCard(english:' not in app:
    raise SystemExit('market strip call not found')

card = r'''class _V14ConfidenceCard extends StatelessWidget {
  final bool english;
  final V13MarketConfidence confidence;
  const _V14ConfidenceCard({required this.english, required this.confidence});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final accent = confidence.manual || !confidence.hasLiveData
        ? const Color(0xFF6D7180)
        : confidence.score >= 70
            ? const Color(0xFF087F5B)
            : confidence.score >= 45
                ? const Color(0xFFC47B00)
                : const Color(0xFFC33A46);
    final badge = confidence.manual
        ? t('MANUELL', 'MANUAL')
        : confidence.hasLiveData
            ? '${confidence.score}/100'
            : t('KEINE LIVE-DATEN', 'NO LIVE DATA');

    return Container(
      key: const ValueKey('v0144-confidence-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_user_outlined, size: 20, color: accent),
          const SizedBox(width: 7),
          Expanded(child: Text(t('MARKT-CONFIDENCE', 'MARKET CONFIDENCE'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
            child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: accent)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(confidence.label(english), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
        if (!confidence.manual && confidence.hasLiveData) ...[
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              key: const ValueKey('v0144-confidence-progress'),
              value: confidence.score / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFEDEEF4),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(confidence.note(english), style: const TextStyle(fontSize: 10.8, height: 1.35, color: Color(0xFF686C79))),
      ]),
    );
  }
}

'''
marker = 'class _V13MarketStrip extends StatelessWidget {'
if 'class _V14ConfidenceCard extends StatelessWidget {' not in app:
    if marker not in app:
        raise SystemExit('V13MarketStrip marker not found')
    app = app.replace(marker, card + marker, 1)

assert "ValueKey('v0144-confidence-card')" in app
assert "ValueKey('v0144-confidence-progress')" in app
app_path.write_text(app)
print('V0.14.4 confidence UI applied')
