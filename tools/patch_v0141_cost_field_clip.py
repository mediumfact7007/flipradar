from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

# V0.14.1: the outlined TextField's floating label extends above its own box.
# Inside ExpansionTile this can be clipped at the top edge on compact Android
# screens. Give the first child dedicated breathing room so the complete label
# stays inside the expanded child viewport.
needle = """            children: [
              TextField(controller: costs, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Zusatzkosten gesamt', 'Extra costs total'), suffixText: '€')),
              const SizedBox(height: 8),
"""
replacement = """            children: [
              const SizedBox(height: 12, key: ValueKey('v0141-cost-label-top-space')),
              TextField(
                key: const ValueKey('v0141-extra-costs-input'),
                controller: costs,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 8),
"""

if needle in app:
    app = app.replace(needle, replacement, 1)
elif "v0141-cost-label-top-space" not in app:
    raise SystemExit('Costs ExpansionTile field pattern not found')

pub = pub.replace('version: 0.14.0+23', 'version: 0.14.1+24')

assert 'version: 0.14.1+24' in pub
assert "v0141-cost-label-top-space" in app
assert "v0141-extra-costs-input" in app
assert "labelText: t('Zusatzkosten gesamt', 'Extra costs total')" in app
assert "const SizedBox(height: 14)" in app

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.1 cost-field clipping fix applied')
