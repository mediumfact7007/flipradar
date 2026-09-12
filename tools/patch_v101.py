from pathlib import Path

p = Path('lib/v10_app.dart')
s = p.read_text()

# 1) Guard BuildContext on every continuous-scan iteration.
old = '''  Future<void> _scanSession() async {
    var keepGoing = true;
    while (mounted && keepGoing) {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
      );
      if (!mounted || code == null || code.trim().isEmpty) return;
      keepGoing = await _openCheck(code.trim());
    }
  }'''
new = '''  Future<void> _scanSession() async {
    var keepGoing = true;
    while (keepGoing) {
      if (!mounted) return;
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
      );
      if (!mounted || code == null || code.trim().isEmpty) return;
      keepGoing = await _openCheck(code.trim());
    }
  }'''
if old not in s:
    raise SystemExit('scan-session block not found')
s = s.replace(old, new, 1)

# 2) Share hint is informational. It must not accidentally open Saved.
old = '''        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onSaved,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.ios_share_rounded, size: 19, color: Color(0xFF4E50D8)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    t('Online-Angebot? Teilen → FlipRadar', 'Online listing? Share → FlipRadar'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF4E50D8)),
                  ),
                ),
              ],
            ),
          ),
        ),'''
new = '''        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.ios_share_rounded, size: 19, color: Color(0xFF4E50D8)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('Online-Angebot? Im Teilen-Menü → FlipRadar', 'Online listing? Share menu → FlipRadar'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF4E50D8)),
                ),
              ),
            ],
          ),
        ),'''
if old not in s:
    raise SystemExit('share-hint block not found')
s = s.replace(old, new, 1)

# 3) Prevent stale market data / stale decision when the item text changes.
old = '''  bool showDetails = false;
  int _searchToken = 0;
  List<SourceListing> listings = [];'''
new = '''  bool showDetails = false;
  int _searchToken = 0;
  String _lastSearchedQuery = '';
  _FastDecision? _lastHapticDecision;
  List<SourceListing> listings = [];'''
if old not in s:
    raise SystemExit('state fields block not found')
s = s.replace(old, new, 1)

anchor = '''  double _value(TextEditingController c) => parseMoneyInput(c.text);

  Future<void> _search() async {'''
replacement = '''  double _value(TextEditingController c) => parseMoneyInput(c.text);

  void _queryChanged(String raw) {
    final current = raw.trim();
    if (!searched || current == _lastSearchedQuery) return;
    _searchToken++;
    setState(() {
      loading = false;
      searched = false;
      listings = [];
      showManual = false;
      manualSell.clear();
      buy.clear();
      _lastHapticDecision = null;
    });
  }

  Future<void> _search() async {'''
if anchor not in s:
    raise SystemExit('query-change insertion anchor not found')
s = s.replace(anchor, replacement, 1)

old = '''    widget.onHistory(q);
    final token = ++_searchToken;
    setState(() {'''
new = '''    widget.onHistory(q);
    final token = ++_searchToken;
    _lastSearchedQuery = q;
    _lastHapticDecision = null;
    setState(() {'''
if old not in s:
    raise SystemExit('search-token block not found')
s = s.replace(old, new, 1)

old = '''          TextField(
            controller: query,
            onSubmitted: (_) => _search(),'''
new = '''          TextField(
            controller: query,
            onChanged: _queryChanged,
            onSubmitted: (_) => _search(),'''
if old not in s:
    raise SystemExit('query TextField block not found')
s = s.replace(old, new, 1)

# 4) Haptic feedback only when the recommendation state actually changes.
old = '''            onChanged: (_) {
              setState(() {});
              if (decision != _FastDecision.waiting) HapticFeedback.selectionClick();
            },'''
new = '''            onChanged: (_) {
              setState(() {});
              final current = decision;
              if (current != _FastDecision.waiting && current != _lastHapticDecision) {
                _lastHapticDecision = current;
                HapticFeedback.selectionClick();
              }
            },'''
if old not in s:
    raise SystemExit('haptic block not found')
s = s.replace(old, new, 1)

p.write_text(s)

# Version bump.
p = Path('pubspec.yaml')
s = p.read_text()
if 'version: 0.10.0+11' not in s:
    raise SystemExit('unexpected pubspec version')
p.write_text(s.replace('version: 0.10.0+11', 'version: 0.10.1+12', 1))

# Add regression coverage for changing an item after a completed manual check.
p = Path('test/v10_flow_test.dart')
s = p.read_text()
needle = '''  testWidgets('V0.10 manual fallback produces an immediate buy decision', (tester) async {'''
if needle not in s:
    raise SystemExit('V0.10 test anchor not found')
extra = r'''
  testWidgets('V0.10 clears a stale decision when the item changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FastCheckPage(
          english: false,
          initialQuery: 'Testgerät',
          targetRoi: 35,
          plan: UserPlan.free,
          sources: const [],
          onHistory: (_) {},
          onWatch: (_) {},
          onAddFlip: (_) {},
          onRemoveFlip: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Anderes Gerät');
    await tester.pump();
    expect(find.text('KAUFEN'), findsNothing);
  });

'''
s = s.replace(needle, extra + needle, 1)
p.write_text(s)
