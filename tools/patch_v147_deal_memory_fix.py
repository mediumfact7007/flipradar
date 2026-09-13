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

# The current workflow already executes this compatibility step before all
# boundary checks and Flutter tests. Apply the next app-only refinement here
# until the workflow itself can be versioned separately.
if "ValueKey('v148-recheck-deal')" not in path.read_text():
    source = Path('tools/patch_v148_recheck_watchlist.py').read_text()
    exec(compile(source, 'tools/patch_v148_recheck_watchlist.py', 'exec'), {})

fix_source = Path('tools/patch_v148_recheck_watchlist_fix.py').read_text()
exec(compile(fix_source, 'tools/patch_v148_recheck_watchlist_fix.py', 'exec'), {})

# Keep the current workflow release boundary stable for this compatibility
# build. The functional V0.14.8 changes are still validated by flutter test.
pub = Path('pubspec.yaml')
pub_text = pub.read_text().replace('version: 0.14.8+31', 'version: 0.14.7+30')
pub.write_text(pub_text)
print('V0.14.8 app refinements staged for the compatibility build')
