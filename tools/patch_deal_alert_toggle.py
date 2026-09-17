from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()

import_line = "import 'deal_alert_toggle.dart';\n"
import_anchor = "import 'buyback_summary_card.dart';\n"
if import_line not in text:
    if text.count(import_anchor) != 1:
        raise SystemExit('Expected exactly one import anchor')
    text = text.replace(import_anchor, import_anchor + import_line, 1)

widget_line = "          DealAlertToggle(flipId: flip.id, english: english),\n          const SizedBox(height: 8),\n"
action_anchor = "        if (!sold && !archived) ...[\n          const SizedBox(height: 10),\n          if (saved)\n"
replacement = "        if (saved) ...[\n          const SizedBox(height: 8),\n          DealAlertToggle(flipId: flip.id, english: english),\n        ],\n        if (!sold && !archived) ...[\n          const SizedBox(height: 10),\n          if (saved)\n"
if "DealAlertToggle(flipId: flip.id, english: english)" not in text:
    if text.count(action_anchor) != 1:
        raise SystemExit('Expected exactly one saved-deal action anchor')
    text = text.replace(action_anchor, replacement, 1)

if text.count(import_line) != 1:
    raise SystemExit('Deal alert toggle import must occur exactly once')
if text.count("DealAlertToggle(flipId: flip.id, english: english)") != 1:
    raise SystemExit('Deal alert toggle must occur exactly once')

path.write_text(text)
