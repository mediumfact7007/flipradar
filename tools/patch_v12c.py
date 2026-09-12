from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise RuntimeError(f'{path}: missing expected block')
    p.write_text(text.replace(old, new, 1))


# Do not show a second warning card above the manual sale-price field. The
# compact FLIP-DATEN summary already communicates that the market value is
# unavailable and keeps the actual input/action above the fold.
replace_once(
    'lib/v10_app.dart',
    """              if (sell == null)
                _MissingValueCard(
                  english: widget.english,
                  retail: retailMedian,
                ),
              if (sell == null) const SizedBox(height: 10),
""",
    """""",
)

# Replace the tall metric-card composition with a compact sourcing snapshot.
p = Path('lib/v10_app.dart')
text = p.read_text()
start = text.find('class _FlipDataCard extends StatelessWidget {')
end = text.find('class _FastDecisionCard extends StatelessWidget {', start)
if start < 0 or end < 0:
    raise RuntimeError('Could not locate FLIP-DATEN widget block')
compact = r'''class _FlipDataCard extends StatelessWidget {
  final bool english;
  final double? expectedSale;
  final double? resaleMedian;
  final double? resaleLow;
  final double? resaleHigh;
  final int compareCount;
  final double? retail;
  final double? buyback;
  final String confidence;
  final double targetRoi;
  final double minProfit;

  const _FlipDataCard({
    required this.english,
    required this.expectedSale,
    required this.resaleMedian,
    required this.resaleLow,
    required this.resaleHigh,
    required this.compareCount,
    required this.retail,
    required this.buyback,
    required this.confidence,
    required this.targetRoi,
    required this.minProfit,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final saleText = expectedSale == null ? '—' : euro(expectedSale!);
    final rangeText = resaleLow == null || resaleHigh == null
        ? '—'
        : '${euro(resaleLow!)}–${euro(resaleHigh!)}';
    final medianText = resaleMedian == null ? '—' : euro(resaleMedian!);
    final refs = <String>[
      if (retail != null) t('Neu ${euro(retail!)}', 'Retail ${euro(retail!)}'),
      if (buyback != null) t('Ankauf ${euro(buyback!)}', 'Buyback ${euro(buyback!)}'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF24234A),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(t('FLIP-DATEN', 'FLIP DATA'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: .3)),
              const Spacer(),
              Text(
                t('Qualität: $confidence', 'Quality: $confidence'),
                style: const TextStyle(color: Color(0xFFBFC0D8), fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _CompactFlipMetric(label: t('VERKAUF CA.', 'SALE EST.'), value: saleText, strong: true)),
              const SizedBox(width: 7),
              Expanded(child: _CompactFlipMetric(label: t('AKTIVE VERGLEICHE', 'ACTIVE COMPS'), value: '$compareCount')),
              const SizedBox(width: 7),
              Expanded(child: _CompactFlipMetric(label: t('MEDIAN', 'MEDIAN'), value: medianText)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t('Spanne $rangeText', 'Range $rangeText'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFD6D6EB), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t('${targetRoi.toStringAsFixed(0)}% ROI · ${euro(minProfit)}+', '${targetRoi.toStringAsFixed(0)}% ROI · ${euro(minProfit)}+'),
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(refs.join(' · '), style: const TextStyle(color: Color(0xFFC7C8DE), fontSize: 10.5)),
          ],
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFFAEB0CE), size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  t('Verkaufstempo/Sell-through: offen bis bestätigte Verkaufsdaten vorliegen.', 'Sell-through: pending until confirmed sales data is available.'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFAEB0CE), fontSize: 9.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactFlipMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _CompactFlipMetric({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAEB0CE), fontSize: 8.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: strong ? 16 : 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

'''
p.write_text(text[:start] + compact + text[end:])

# Update tests for the denser search-first flow. Tests that target a control
# below the current viewport explicitly scroll to it; this verifies it remains
# in the main flow without requiring Details to be opened.
p = Path('test/v10_flow_test.dart')
text = p.read_text()
text = text.replace("    expect(find.text('MARKTWERT NOCH NICHT SICHER'), findsOneWidget);\n", "    expect(find.text('FLIP-DATEN'), findsOneWidget);\n", 1)

# Add a small helper-style scroll before manual fields in legacy flow tests.
text = text.replace(
    "    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');",
    "    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.drag(find.byType(ListView), const Offset(0, -180));\n    await tester.pump();\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');",
    1,
)
text = text.replace(
    "    expect(find.byKey(const ValueKey('buy-price-input')), findsOneWidget);\n    expect(find.byKey(const ValueKey('manual-sale-price-input')), findsOneWidget);\n\n    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');",
    "    expect(find.byKey(const ValueKey('buy-price-input')), findsOneWidget);\n    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.drag(find.byType(ListView), const Offset(0, -180));\n    await tester.pump();\n    expect(find.byKey(const ValueKey('manual-sale-price-input')), findsOneWidget);\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');",
    1,
)
text = text.replace(
    "    final saleField = find.byKey(const ValueKey('manual-sale-price-input'));\n    expect(saleField, findsOneWidget);",
    "    await tester.drag(find.byType(ListView), const Offset(0, -180));\n    await tester.pump();\n    final saleField = find.byKey(const ValueKey('manual-sale-price-input'));\n    expect(saleField, findsOneWidget);",
    1,
)
text = text.replace(
    "    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '80');\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '100');",
    "    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '80');\n    await tester.drag(find.byType(ListView), const Offset(0, -180));\n    await tester.pump();\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '100');",
    1,
)
text = text.replace(
    "    expect(find.text('WO WILLST DU VERGLEICHEN?'), findsOneWidget);",
    "    await tester.drag(find.byType(ListView), const Offset(0, -520));\n    await tester.pump();\n    expect(find.text('WO WILLST DU VERGLEICHEN?'), findsOneWidget);",
    1,
)
p.write_text(text)

print('FlipRadar V0.12 compact flip-data patch applied.')
