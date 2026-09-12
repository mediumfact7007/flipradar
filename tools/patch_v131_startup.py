from pathlib import Path

# FlipRadar V0.13.1: rescue startup path. Keep optional native integrations
# out of the critical first-launch path and make persisted-data loading fail-safe.

pub = Path('pubspec.yaml')
if pub.exists():
    text = pub.read_text()
    text = text.replace('version: 0.13.0+16', 'version: 0.13.1+17')
    pub.write_text(text)

main = Path('lib/main.dart')
if main.exists():
    text = main.read_text()
    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text
    old = """void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipRadarV13App());
}
"""
    new = """void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () => runApp(const FlipRadarV13App()),
    (error, stack) {
      // Keep asynchronous Dart/plugin errors from tearing down the UI.
      // Production builds will forward these to crash reporting later.
    },
  );
}
"""
    if old in text:
        text = text.replace(old, new)
    main.write_text(text)

p = Path('lib/v13_app.dart')
text = p.read_text()

# Do not touch billing/consent/ads in the critical app startup path.
text = text.replace('    _load();\n', '    unawaited(_loadSafe());\n', 1)
text = text.replace('    unawaited(monetization.init());\n', '')

# Do not initialize receive_sharing_intent while the root UI is mounting.
# It remains compiled and can be re-enabled after this startup regression is isolated.
text = text.replace('    _listenShares();\n', '    // Safe-start build: optional share listener is not part of first-frame startup.\n', 1)

if 'Future<void> _loadSafe() async {' not in text:
    marker = '  Future<void> _load() async {\n'
    safe = """  Future<void> _loadSafe() async {
    try {
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // A corrupt/incompatible preference from an older prototype must never
        // prevent FlipRadar from opening. Start with sane local defaults.
        english = false;
        backend = '';
        targetRoi = 35;
        minProfit = 20;
        plan = UserPlan.free;
        taxMode = V13TaxMode.privateSeller;
        flips = <V13Flip>[];
        history = <String>[];
        sources = SourceRegistry.builtIns();
        loading = false;
      });
    }
  }

"""
    if marker not in text:
        raise SystemExit('Could not find V0.13 load method')
    text = text.replace(marker, safe + marker, 1)

p.write_text(text)
print('V0.13.1 safe-start patch applied')
