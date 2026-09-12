from pathlib import Path


def rep(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise RuntimeError(f'{path}: missing expected block')
    p.write_text(text.replace(old, new, 1))


# Keep the market summary first, but do not let the source grid push the price
# inputs below the fold. Sources remain visible before Details.
rep(
    'lib/v10_app.dart',
    """            _FlipDataCard(
              english: widget.english,
              expectedSale: sell,
              resaleMedian: resaleMedian,
              resaleLow: resaleLow,
              resaleHigh: resaleHigh,
              compareCount: cleanedResale.length,
              retail: retailMedian,
              buyback: buybackMedian,
              confidence: _confidenceText(),
              targetRoi: widget.targetRoi,
              minProfit: widget.minProfit,
            ),
            const SizedBox(height: 12),
            _QuickCompareSection(
              english: widget.english,
              sources: enabled,
              sourcePrices: sourcePrices,
              onEbaySold: _openEbaySold,
              onOpenSource: _openSource,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buy,
""",
    """            _FlipDataCard(
              english: widget.english,
              expectedSale: sell,
              resaleMedian: resaleMedian,
              resaleLow: resaleLow,
              resaleHigh: resaleHigh,
              compareCount: cleanedResale.length,
              retail: retailMedian,
              buyback: buybackMedian,
              confidence: _confidenceText(),
              targetRoi: widget.targetRoi,
              minProfit: widget.minProfit,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('buy-price-input'),
              controller: buy,
""",
)

rep(
    'lib/v10_app.dart',
    """            ],
            const SizedBox(height: 10),
            ExpansionTile(
""",
    """            ],
            const SizedBox(height: 14),
            _QuickCompareSection(
              english: widget.english,
              sources: enabled,
              sourcePrices: sourcePrices,
              onEbaySold: _openEbaySold,
              onOpenSource: _openSource,
            ),
            const SizedBox(height: 10),
            ExpansionTile(
""",
)

# Make tests target semantic fields rather than fragile numeric positions.
p = Path('test/v10_flow_test.dart')
text = p.read_text()
text = text.replace("    final fields = find.byType(TextField);\n    await tester.enterText(fields.at(1), '100');\n    await tester.enterText(fields.at(2), '200');", "    final fields = find.byType(TextField);\n    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');", 1)
text = text.replace("    final fields = find.byType(TextField);\n    expect(fields.evaluate().length, greaterThanOrEqualTo(3));\n\n    await tester.enterText(fields.at(1), '100');\n    await tester.enterText(fields.at(2), '200');", "    expect(find.byKey(const ValueKey('buy-price-input')), findsOneWidget);\n    expect(find.byKey(const ValueKey('manual-sale-price-input')), findsOneWidget);\n\n    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '100');\n    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '200');", 1)
text = text.replace("    final buyField = find.byType(TextField).at(1);", "    final buyField = find.byKey(const ValueKey('buy-price-input'));", 1)
text = text.replace("    final fields = find.byType(TextField);\n    await tester.enterText(fields.at(1), '80');", "    await tester.enterText(find.byKey(const ValueKey('buy-price-input')), '80');", 1)
p.write_text(text)

print('FlipRadar V0.12 action-order refinement applied.')
