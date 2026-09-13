from pathlib import Path

# SAFE START is already persisted on main. This bridge is intentionally a no-op
# so the current CI can reproduce the confirmed-good build once more.
app = Path('lib/v13_app.dart')
pub = Path('pubspec.yaml')
assert app.exists() and pub.exists()
assert 'version: 0.13.3+19' in pub.read_text()
print('V0.13.3 SAFE START already persisted; no patch required')
