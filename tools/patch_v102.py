from pathlib import Path

app = Path('lib/v10_app.dart')
text = app.read_text()

replacements = [
(
"""  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '0');
  final buyFocus = FocusNode();
  bool loading = false;""",
"""  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '0');
  final buyFocus = FocusNode();
  final manualSellFocus = FocusNode();
  double? _manualSellCommitted;
  bool loading = false;"""
),
(
"""    costs.dispose();
    buyFocus.dispose();
    super.dispose();""",
"""    costs.dispose();
    buyFocus.dispose();
    manualSellFocus.dispose();
    super.dispose();"""
),
(
"""      manualSell.clear();
      buy.clear();
      _lastHapticDecision = null;""",
"""      manualSell.clear();
      _manualSellCommitted = null;
      buy.clear();
      _lastHapticDecision = null;"""
),
(
"""      listings = [];
      manualSell.clear();
      showManual = false;""",
"""      listings = [];
      manualSell.clear();
      _manualSellCommitted = null;
      showManual = false;"""
),
(
"""  double? get targetSell {
    final manual = _value(manualSell);
    if (manual > 0) return manual;
    final med = resaleMedian;
    return med == null ? null : med * 0.90;
  }""",
"""  double? get targetSell {
    final manual = _manualSellCommitted;
    if (manual != null && manual > 0) return manual;
    final med = resaleMedian;
    return med == null ? null : med * 0.90;
  }"""
),
(
"""  int get confidenceLevel {
    if (_value(manualSell) > 0) return 0;""",
"""  int get confidenceLevel {
    if (_manualSellCommitted != null) return 0;"""
),
(
"""  Future<void> _openEbaySold() async {""",
"""  void _commitManualSell() {
    final parsed = _value(manualSell);
    if (parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Bitte einen Verkaufspreis größer als 0 eingeben.', 'Enter a sale price greater than 0.'))),
      );
      return;
    }
    setState(() {
      _manualSellCommitted = parsed;
      showManual = false;
      _lastHapticDecision = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _editManualSell() {
    final current = targetSell;
    if (_manualSellCommitted == null && current != null && manualSell.text.trim().isEmpty) {
      manualSell.text = current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 2).replaceAll('.', ',');
      manualSell.selection = TextSelection.collapsed(offset: manualSell.text.length);
    }
    setState(() {
      _manualSellCommitted = null;
      showManual = true;
      _lastHapticDecision = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) manualSellFocus.requestFocus();
    });
  }

  Future<void> _openEbaySold() async {"""
),
(
"""    final enabled = widget.sources.where((s) => s.enabled).toList();

    return Scaffold(""",
"""    final enabled = widget.sources.where((s) => s.enabled).toList();
    final enteringManualSell = showManual && _manualSellCommitted == null;

    return Scaffold("""
),
(
"""            if (sell == null) ...[
              _MissingValueCard(
                english: widget.english,
                retail: retailMedian,
                onEbaySold: _openEbaySold,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: manualSell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: 'z. B. 250',
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
              ),
            ] else ...[""",
"""            if (sell == null || enteringManualSell) ...[
              if (sell == null)
                _MissingValueCard(
                  english: widget.english,
                  retail: retailMedian,
                  onEbaySold: _openEbaySold,
                ),
              if (sell == null) const SizedBox(height: 10),
              TextField(
                key: const ValueKey('manual-sale-price-input'),
                controller: manualSell,
                focusNode: manualSellFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _commitManualSell(),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: 'z. B. 250',
                  helperText: t('Erst mit ✓ oder „Übernehmen“ bestätigen.', 'Confirm with ✓ or “Apply”.'),
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.sell_outlined),
                  suffixIcon: IconButton(
                    tooltip: t('Übernehmen', 'Apply'),
                    onPressed: _value(manualSell) > 0 ? _commitManualSell : null,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('commit-manual-sale-price'),
                  onPressed: _value(manualSell) > 0 ? _commitManualSell : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t('VERKAUFSPREIS ÜBERNEHMEN', 'APPLY SALE PRICE')),
                ),
              ),
            ] else ...["""
),
(
"""              _FastDecisionCard(
                english: widget.english,
                decision: decision,
                maxBuy: max,
                sell: sell,
                profit: p,
                roi: r,
              ),
              if (negotiationOffer != null""",
"""              _FastDecisionCard(
                english: widget.english,
                decision: decision,
                maxBuy: max,
                sell: sell,
                profit: p,
                roi: r,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _editManualSell,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(t('Verkaufspreis ändern', 'Change sale price')),
                ),
              ),
              if (negotiationOffer != null"""
),
(
"""  String _confidenceText() {
    if (_value(manualSell) > 0) return t('manuell', 'manual');""",
"""  String _confidenceText() {
    if (_manualSellCommitted != null) return t('manuell', 'manual');"""
),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one match, got {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)

app.write_text(text)

# Update version only once.
pub = Path('pubspec.yaml')
pub_text = pub.read_text()
if 'version: 0.10.1+12' not in pub_text:
    raise SystemExit('Unexpected pubspec version')
pub.write_text(pub_text.replace('version: 0.10.1+12', 'version: 0.10.2+13', 1))

# Update V0.10 tests for explicit manual-price confirmation and add regression coverage.
test = Path('test/v10_flow_test.dart')
t = test.read_text()

t = t.replace(
"""    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);""",
"""    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('commit-manual-sale-price')));
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);""",
1,
)

t = t.replace(
"""    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();

    expect(find.text('KAUFEN'), findsOneWidget);""",
"""    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '200');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('commit-manual-sale-price')));
    await tester.pump();

    expect(find.text('KAUFEN'), findsOneWidget);""",
1,
)

insert = r'''

  testWidgets('V0.10.2 lets the full manual sale price be typed before applying it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FastCheckPage(
          english: false,
          initialQuery: 'iPhone 17',
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

    final saleField = find.byKey(const ValueKey('manual-sale-price-input'));
    expect(saleField, findsOneWidget);

    await tester.enterText(saleField, '2');
    await tester.pump();
    expect(saleField, findsOneWidget);
    expect(find.text('KAUFEN'), findsNothing);

    await tester.enterText(saleField, '250');
    await tester.pump();
    expect(saleField, findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('KAUFEN'), findsNothing);

    final buyField = find.byType(TextField).at(1);
    await tester.enterText(buyField, '100');
    await tester.pump();
    expect(saleField, findsOneWidget);
    expect(find.text('KAUFEN'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('commit-manual-sale-price')));
    await tester.pump();
    expect(saleField, findsNothing);
    expect(find.text('KAUFEN'), findsOneWidget);
  });
'''

marker = '\n}\n'
pos = t.rfind(marker)
if pos < 0:
    raise SystemExit('Could not find end of v10 test file')
t = t[:pos] + insert + t[pos:]
test.write_text(t)
