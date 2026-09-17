from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()

import_line = "import 'deal_alert_result_card.dart';\n"
anchor_import = "import 'deal_alert_toggle.dart';\n"
if import_line not in text:
    if anchor_import not in text:
        raise SystemExit('deal alert toggle import anchor missing')
    text = text.replace(anchor_import, anchor_import + import_line, 1)

marker = "DealAlertResultCard(\n              flipId: widget.existingSnapshot!.id,"
if marker not in text:
    needle = """            RecheckDeltaCard(
              english: widget.english,
              delta: RecheckDelta.compare(
                previousAsking: widget.existingSnapshot!.buy,
                currentAsking: buyPrice,
                previousMaxBuy: widget.existingSnapshot!.maxBuyAtCheck,
                currentMaxBuy: maxBuy ?? 0,
                previousProfit: widget.existingSnapshot!.profitAtCheck,
                currentProfit: profit,
                previousRoi: widget.existingSnapshot!.roiAtCheck,
                currentRoi: roi,
              ),
            ),"""
    if text.count(needle) != 1:
        raise SystemExit(f'expected exactly one recheck result anchor, found {text.count(needle)}')
    addition = needle + """
            const SizedBox(height: 8),
            DealAlertResultCard(
              flipId: widget.existingSnapshot!.id,
              english: widget.english,
              previousProfit: widget.existingSnapshot!.profitAtCheck,
              currentProfit: profit,
              previousRoi: widget.existingSnapshot!.roiAtCheck,
              currentRoi: roi,
            ),"""
    text = text.replace(needle, addition, 1)

if text.count(import_line) != 1:
    raise SystemExit('deal alert result import must occur exactly once')
if text.count(marker) != 1:
    raise SystemExit('deal alert result card must occur exactly once')

path.write_text(text)
