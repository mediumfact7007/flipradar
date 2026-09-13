from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

# Fix the bottom edge of the expanded cost/calculation section. On compact
# Android screens the final target hint was visually colliding with the
# ExpansionTile divider. Keep explicit breathing room inside the section.
needle = """              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text(t('Ziel: ${widget.targetRoi.toStringAsFixed(0)} % ROI + mindestens ${v13Euro(widget.minProfit)} Gewinn.', 'Target: ${widget.targetRoi.toStringAsFixed(0)}% ROI + at least ${v13Euro(widget.minProfit)} profit.'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF707483)))),
"""
replacement = needle + "              const SizedBox(height: 14),\n"

if "const SizedBox(height: 14),\n            ],\n          ),\n          if (widget.plan == UserPlan.free)" not in app:
    if needle not in app:
        raise SystemExit('Cost/calculation target hint marker not found')
    app = app.replace(needle, replacement, 1)

pub = pub.replace('version: 0.13.5+21', 'version: 0.13.6+22')

assert 'version: 0.13.6+22' in pub
assert needle in app
assert replacement in app

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.13.6 compact-screen spacing fix applied')
