from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()
app = app.replace(
    r"RegExp(r'https?://[^\\\\s]+', caseSensitive: false)",
    r"RegExp(r'https?://[^\s]+', caseSensitive: false)",
)
app = app.replace(
    r"RegExp(r'https?://[^\\s]+', caseSensitive: false)",
    r"RegExp(r'https?://[^\s]+', caseSensitive: false)",
)
path.write_text(app)
print('V0.14.7 URL regex normalized')

# The workflow executes this compatibility step before boundary checks and
# Flutter tests. Ensure the V0.14.8 app-only refinement is present without
# changing the validated release metadata in pubspec.yaml.
if "ValueKey('v148-recheck-deal')" not in path.read_text():
    source = Path('tools/patch_v148_recheck_watchlist.py').read_text()
    exec(compile(source, 'tools/patch_v148_recheck_watchlist.py', 'exec'), {})

fix_source = Path('tools/patch_v148_recheck_watchlist_fix.py').read_text()
exec(compile(fix_source, 'tools/patch_v148_recheck_watchlist_fix.py', 'exec'), {})

if "import 'recheck_delta.dart';" not in path.read_text():
    source = Path('tools/patch_v149_recheck_card.py').read_text()
    exec(compile(source, 'tools/patch_v149_recheck_card.py', 'exec'), {})

print('V0.14.9 app refinements staged for the compatibility build')
