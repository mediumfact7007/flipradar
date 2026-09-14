from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()

if "import 'recheck_delta.dart';" not in app:
    app = app.replace("import 'source_registry.dart';", "import 'recheck_delta.dart';\nimport 'recheck_delta_card.dart';\nimport 'source_registry.dart';", 1)

marker = "key: const ValueKey('v149-recheck-delta')"
if marker not in app:
    anchor = "          const SizedBox(height: 8),\n          _V14ConfidenceCard(english: widget.english, confidence: marketConfidence),\n"
    insert = "          if (widget.existingSnapshot?.isSaved == true && expectedSale != null && (widget.existingSnapshot!.maxBuyAtCheck > 0 || widget.existingSnapshot!.profitAtCheck != 0 || widget.existingSnapshot!.roiAtCheck != 0)) ...[\n            const SizedBox(height: 8),\n            RecheckDeltaCard(\n              english: widget.english,\n              delta: RecheckDelta.compare(\n                previousAsking: widget.existingSnapshot!.buy,\n                currentAsking: buyPrice,\n                previousMaxBuy: widget.existingSnapshot!.maxBuyAtCheck,\n                currentMaxBuy: maxBuy ?? 0,\n                previousProfit: widget.existingSnapshot!.profitAtCheck,\n                currentProfit: profit,\n                previousRoi: widget.existingSnapshot!.roiAtCheck,\n                currentRoi: roi,\n              ),\n            ),\n          ],\n          const SizedBox(height: 8),\n          _V14ConfidenceCard(english: widget.english, confidence: marketConfidence),\n"
    if anchor not in app:
        raise SystemExit('V0.14.9 recheck card anchor not found')
    app = app.replace(anchor, insert, 1)

path.write_text(app)
print('V0.14.9 recheck trend card staged')
