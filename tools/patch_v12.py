from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected exactly one match, found {count}')
    p.write_text(text.replace(old, new, 1))


# Version.
replace_once('pubspec.yaml', 'version: 0.11.0+14', 'version: 0.12.0+15')

# Persist a second profitability guardrail: minimum euro profit as well as ROI.
replace_once(
    'lib/v10_app.dart',
    """  double targetRoi = 35;
  UserPlan plan = UserPlan.free;
""",
    """  double targetRoi = 35;
  double minProfit = 20;
  UserPlan plan = UserPlan.free;
""",
)
replace_once(
    'lib/v10_app.dart',
    """      final rawRoi = p.getDouble('roi_v10') ?? p.getDouble('roi_v09') ?? 35;
      setState(() {
""",
    """      final rawRoi = p.getDouble('roi_v10') ?? p.getDouble('roi_v09') ?? 35;
      final rawMinProfit = p.getDouble('min_profit_v12') ?? 20;
      setState(() {
""",
)
replace_once(
    'lib/v10_app.dart',
    """        targetRoi = rawRoi.isFinite ? rawRoi.clamp(10, 100).toDouble() : 35.0;
        plan = UserPlan.values[rawPlan.clamp(0, UserPlan.values.length - 1)];
""",
    """        targetRoi = rawRoi.isFinite ? rawRoi.clamp(10, 100).toDouble() : 35.0;
        minProfit = rawMinProfit.isFinite ? rawMinProfit.clamp(0, 500).toDouble() : 20.0;
        plan = UserPlan.values[rawPlan.clamp(0, UserPlan.values.length - 1)];
""",
)
replace_once(
    'lib/v10_app.dart',
    """      await p.setDouble('roi_v10', targetRoi);
      await p.setInt('plan_preview_v10', plan.index);
""",
    """      await p.setDouble('roi_v10', targetRoi);
      await p.setDouble('min_profit_v12', minProfit);
      await p.setInt('plan_preview_v10', plan.index);
""",
)
replace_once(
    'lib/v10_app.dart',
    """              targetRoi: targetRoi,
              plan: plan,
""",
    """              targetRoi: targetRoi,
              minProfit: minProfit,
              plan: plan,
""",
)
replace_once(
    'lib/v10_app.dart',
    """              onRoi: (v) {
                setState(() => targetRoi = v.isFinite ? v.clamp(10, 100).toDouble() : 35.0);
                _save();
              },
              onPlan: (v) {
""",
    """              onRoi: (v) {
                setState(() => targetRoi = v.isFinite ? v.clamp(10, 100).toDouble() : 35.0);
                _save();
              },
              onMinProfit: (v) {
                setState(() => minProfit = v.isFinite ? v.clamp(0, 500).toDouble() : 20.0);
                _save();
              },
              onPlan: (v) {
""",
)

# Shell carries the minimum-profit preference to settings and deal checks.
replace_once(
    'lib/v10_app.dart',
    """  final double targetRoi;
  final UserPlan plan;
""",
    """  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
""",
)
replace_once(
    'lib/v10_app.dart',
    """  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlan;
""",
    """  final ValueChanged<double> onRoi;
  final ValueChanged<double> onMinProfit;
  final ValueChanged<UserPlan> onPlan;
""",
)
replace_once(
    'lib/v10_app.dart',
    """    required this.targetRoi,
    required this.plan,
""",
    """    required this.targetRoi,
    required this.minProfit,
    required this.plan,
""",
)
replace_once(
    'lib/v10_app.dart',
    """    required this.onRoi,
    required this.onPlan,
""",
    """    required this.onRoi,
    required this.onMinProfit,
    required this.onPlan,
""",
)
replace_once(
    'lib/v10_app.dart',
    """            targetRoi: widget.targetRoi,
            plan: widget.plan,
""",
    """            targetRoi: widget.targetRoi,
            minProfit: widget.minProfit,
            plan: widget.plan,
""",
)
replace_once(
    'lib/v10_app.dart',
    """          targetRoi: widget.targetRoi,
          plan: widget.plan,
          sources: widget.sources,
          onLanguage: widget.onLanguage,
          onBackend: widget.onBackend,
          onRoi: widget.onRoi,
          onPlanPreview: widget.onPlan,
""",
    """          targetRoi: widget.targetRoi,
          minProfit: widget.minProfit,
          plan: widget.plan,
          sources: widget.sources,
          onLanguage: widget.onLanguage,
          onBackend: widget.onBackend,
          onRoi: widget.onRoi,
          onMinProfit: widget.onMinProfit,
          onPlanPreview: widget.onPlan,
""",
)

# Search should return to search, not unexpectedly force the scanner.
replace_once(
    'lib/v10_app.dart',
    """  Future<void> _search(String q) async {
    final again = await _openCheck(q);
    if (again && mounted) await _scanSession();
  }
""",
    """  Future<void> _search(String q) async {
    await _openCheck(q);
  }
""",
)

# The inventory tab no longer advertises scanning as the primary floating action.
replace_once(
    'lib/v10_app.dart',
    """      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: _scanSession,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(t('SCANNEN', 'SCAN'), style: const TextStyle(fontWeight: FontWeight.w900)),
            )
          : null,
""",
    """""",
)

# Search-first home. Barcode stays useful but is deliberately secondary.
replace_once(
    'lib/v10_app.dart',
    """  void _submit() {
    final q = query.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  @override
""",
    """  void _submit() {
    final q = query.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty || !mounted) return;
    setState(() {
      query.text = value.length > 180 ? value.substring(0, 180) : value;
      query.selection = TextSelection.collapsed(offset: query.text.length);
    });
  }

  @override
""",
)
replace_once(
    'lib/v10_app.dart',
    """        Text(
          t('Lohnt sich das?', 'Worth buying?'),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.0),
        ),
        const SizedBox(height: 7),
        Text(
          t('Scannen. Preis eingeben. Antwort bekommen.', 'Scan. Enter price. Get the answer.'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF737786)),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 86,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF24234A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            onPressed: widget.onScan,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 31),
                const SizedBox(width: 13),
                Text(t('JETZT SCANNEN', 'SCAN NOW'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          controller: query,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t('Produkt, Modell oder EAN suchen', 'Search product, model or EAN'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: _submit, icon: const Icon(Icons.arrow_forward_rounded)),
          ),
        ),
""",
    """        Text(
          t('Was willst du flippen?', 'What do you want to flip?'),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.0),
        ),
        const SizedBox(height: 7),
        Text(
          t('Produkt eingeben → Markt, Verkaufspreis, Max-Kaufpreis & Gewinn prüfen.', 'Enter a product → check market, sale price, max buy & profit.'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF737786), height: 1.35),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('home-search-field'),
          controller: query,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: t('z. B. iPhone 15 Pro 256 GB', 'e.g. iPhone 15 Pro 256 GB'),
            labelText: t('Produkt schnell suchen', 'Quick product search'),
            prefixIcon: const Icon(Icons.search_rounded, size: 25),
            suffixIcon: IconButton(
              tooltip: t('Einfügen', 'Paste'),
              onPressed: _paste,
              icon: const Icon(Icons.content_paste_rounded),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('home-search-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF24234A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t('FLIP PRÜFEN', 'CHECK FLIP'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 9),
            OutlinedButton.icon(
              onPressed: widget.onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
              label: Text(t('Barcode', 'Barcode')),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6E7EF))),
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF4E50D8), size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('Direkt danach: Marktwert · Max zahlen · Gewinn/ROI · Preisquellen', 'Right after: market value · max buy · profit/ROI · price sources'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF565A69), height: 1.3),
                ),
              ),
            ],
          ),
        ),
""",
)

# FastCheck accepts minProfit without breaking legacy/test call sites.
replace_once(
    'lib/v10_app.dart',
    """  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
""",
    """  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
  final List<PriceSource> sources;
""",
)
replace_once(
    'lib/v10_app.dart',
    """    required this.targetRoi,
    required this.plan,
    required this.sources,
""",
    """    required this.targetRoi,
    this.minProfit = 20,
    required this.plan,
    required this.sources,
""",
)

# Require both ROI target and minimum absolute profit.
replace_once(
    'lib/v10_app.dart',
    """  double? get maxBuy {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    return math.max(0, (sell - extraCosts) / (1 + widget.targetRoi / 100));
  }
""",
    """  double? get maxBuy {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    final byRoi = (sell - extraCosts) / (1 + widget.targetRoi / 100);
    final byProfit = sell - extraCosts - math.max(0, widget.minProfit);
    return math.max(0, math.min(byRoi, byProfit));
  }
""",
)

# Bottom action returns users to a fresh search instead of making scanning the default loop.
replace_once(
    'lib/v10_app.dart',
    """            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(t('NÄCHSTEN ARTIKEL SCANNEN', 'SCAN NEXT ITEM'), style: const TextStyle(fontWeight: FontWeight.w900)),
""",
    """            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.search_rounded),
            label: Text(t('NEUE SUCHE', 'NEW SEARCH'), style: const TextStyle(fontWeight: FontWeight.w900)),
""",
)

# Result screen becomes data-first: market snapshot + sources before purchase input.
buy_field = """          const SizedBox(height: 10),
          TextField(
            controller: buy,
            focusNode: buyFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              setState(() {});
              final current = decision;
              if (current != _FastDecision.waiting && current != _lastHapticDecision) {
                _lastHapticDecision = current;
                HapticFeedback.selectionClick();
              }
            },
            decoration: InputDecoration(
              labelText: t('Was sollst du zahlen?', 'What would you pay?'),
              hintText: '0,00',
              suffixText: '€',
              prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded),
            ),
          ),
"""
replace_once('lib/v10_app.dart', buy_field, '')
replace_once(
    'lib/v10_app.dart',
    """    final sourcePrices = <String, double>{};
    for (final source in enabled) {
      final value = _sourceMedian(source.id);
      if (value != null) sourcePrices[source.id] = value;
    }

    return Scaffold(
""",
    """    final sourcePrices = <String, double>{};
    for (final source in enabled) {
      final value = _sourceMedian(source.id);
      if (value != null) sourcePrices[source.id] = value;
    }
    final cleanedResale = _clean(_resaleValues());
    final resaleLow = cleanedResale.isEmpty ? null : cleanedResale.first;
    final resaleHigh = cleanedResale.isEmpty ? null : cleanedResale.last;

    return Scaffold(
""",
)
replace_once(
    'lib/v10_app.dart',
    """          if (searched && !loading) ...[
            const SizedBox(height: 14),
            if (sell == null || enteringManualSell) ...[
""",
    """          if (searched && !loading) ...[
            const SizedBox(height: 14),
            _FlipDataCard(
              english: widget.english,
              expectedSale: sell,
              resaleMedian: resaleMedian,
              resaleLow: resaleLow,
              resaleHigh: resaleHigh,
              compareCount: cleanedResale.length,
              retail: retailMedian,
              buyback: buybackMedian,
              confidence: _confidenceText(),
              targetRoi: widget.targetRoi,
              minProfit: widget.minProfit,
            ),
            const SizedBox(height: 12),
            _QuickCompareSection(
              english: widget.english,
              sources: enabled,
              sourcePrices: sourcePrices,
              onEbaySold: _openEbaySold,
              onOpenSource: _openSource,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buy,
              focusNode: buyFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {});
                final current = decision;
                if (current != _FastDecision.waiting && current != _lastHapticDecision) {
                  _lastHapticDecision = current;
                  HapticFeedback.selectionClick();
                }
              },
              decoration: InputDecoration(
                labelText: t('Was sollst du zahlen?', 'What would you pay?'),
                hintText: '0,00',
                helperText: t(
                  'Dein Ziel: ${widget.targetRoi.toStringAsFixed(0)} % ROI · mind. ${euro(widget.minProfit)} Gewinn',
                  'Your target: ${widget.targetRoi.toStringAsFixed(0)}% ROI · at least ${euro(widget.minProfit)} profit',
                ),
                suffixText: '€',
                prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (sell == null || enteringManualSell) ...[
""",
)
# Remove now-duplicate QuickCompare from below the decision/manual block.
replace_once(
    'lib/v10_app.dart',
    """            const SizedBox(height: 14),
            _QuickCompareSection(
              english: widget.english,
              sources: enabled,
              sourcePrices: sourcePrices,
              onEbaySold: _openEbaySold,
              onOpenSource: _openSource,
            ),
            const SizedBox(height: 10),
            ExpansionTile(
""",
    """            const SizedBox(height: 10),
            ExpansionTile(
""",
)

# Add the concise, honest flipping-data summary before the existing decision card.
replace_once(
    'lib/v10_app.dart',
    """class _FastDecisionCard extends StatelessWidget {
""",
    """class _FlipDataCard extends StatelessWidget {
  final bool english;
  final double? expectedSale;
  final double? resaleMedian;
  final double? resaleLow;
  final double? resaleHigh;
  final int compareCount;
  final double? retail;
  final double? buyback;
  final String confidence;
  final double targetRoi;
  final double minProfit;

  const _FlipDataCard({
    required this.english,
    required this.expectedSale,
    required this.resaleMedian,
    required this.resaleLow,
    required this.resaleHigh,
    required this.compareCount,
    required this.retail,
    required this.buyback,
    required this.confidence,
    required this.targetRoi,
    required this.minProfit,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final range = resaleLow == null || resaleHigh == null
        ? '—'
        : '${euro(resaleLow!)} – ${euro(resaleHigh!)}';
    final sale = expectedSale == null ? '—' : euro(expectedSale!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF24234A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 21),
              const SizedBox(width: 8),
              Text(t('FLIP-DATEN', 'FLIP DATA'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: .4)),
              const Spacer(),
              TinyLabel(text: confidence.toUpperCase(), color: const Color(0xFF34356C), background: Colors.white),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _DarkDataMetric(label: t('Verkauf ca.', 'Sale est.'), value: sale)),
              const SizedBox(width: 8),
              Expanded(child: _DarkDataMetric(label: t('Aktive Vergleiche', 'Active comps'), value: '$compareCount')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _DarkDataMetric(label: t('Angebotsspanne', 'Asking range'), value: range, small: true)),
              const SizedBox(width: 8),
              Expanded(child: _DarkDataMetric(label: t('Aktiver Median', 'Active median'), value: resaleMedian == null ? '—' : euro(resaleMedian!))),
            ],
          ),
          if (retail != null || buyback != null) ...[
            const SizedBox(height: 9),
            Text(
              [
                if (retail != null) t('Neu ≈ ${euro(retail!)}', 'Retail ≈ ${euro(retail!)}'),
                if (buyback != null) t('Sofort-Ankauf ≈ ${euro(buyback!)}', 'Buyback ≈ ${euro(buyback!)}'),
              ].join('  ·  '),
              style: const TextStyle(color: Color(0xFFD6D6EB), fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(color: const Color(0x18FFFFFF), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Ziel: ${targetRoi.toStringAsFixed(0)} % ROI + mind. ${euro(minProfit)} Gewinn', 'Target: ${targetRoi.toStringAsFixed(0)}% ROI + at least ${euro(minProfit)} profit'),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  t('Verkaufstempo/Sell-through: noch offen – erst mit bestätigten Verkaufsdaten.', 'Sell-through/sales velocity: pending until confirmed sales data is available.'),
                  style: const TextStyle(color: Color(0xFFBFC0D8), fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkDataMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool small;

  const _DarkDataMetric({required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF747786), fontSize: 9.8, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: const Color(0xFF20212A), fontSize: small ? 13 : 17, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FastDecisionCard extends StatelessWidget {
""",
)

# Settings: optional fields preserve old callers while V0.12 can persist minimum profit.
replace_once(
    'lib/v07_settings.dart',
    """  final double targetRoi;
  final UserPlan plan;
""",
    """  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
""",
)
replace_once(
    'lib/v07_settings.dart',
    """  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlanPreview;
""",
    """  final ValueChanged<double> onRoi;
  final ValueChanged<double>? onMinProfit;
  final ValueChanged<UserPlan> onPlanPreview;
""",
)
replace_once(
    'lib/v07_settings.dart',
    """    required this.targetRoi,
    required this.plan,
""",
    """    required this.targetRoi,
    this.minProfit = 20,
    required this.plan,
""",
)
replace_once(
    'lib/v07_settings.dart',
    """    required this.onRoi,
    required this.onPlanPreview,
""",
    """    required this.onRoi,
    this.onMinProfit,
    required this.onPlanPreview,
""",
)
replace_once(
    'lib/v07_settings.dart',
    """  late double roi;
  late bool english;
""",
    """  late double roi;
  late double minProfit;
  late bool english;
""",
)
replace_once(
    'lib/v07_settings.dart',
    """    roi = widget.targetRoi.clamp(10, 100).toDouble();
    english = widget.english;
""",
    """    roi = widget.targetRoi.clamp(10, 100).toDouble();
    minProfit = widget.minProfit.clamp(0, 500).toDouble();
    english = widget.english;
""",
)
replace_once(
    'lib/v07_settings.dart',
    """                Row(
                  children: [25.0, 35.0, 50.0].map((v) {
                    final selected = (roi - v).abs() < 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Center(child: Text(v == 25 ? t('Locker', 'Light') : v == 35 ? t('Standard', 'Standard') : t('Hoch', 'High'))),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => roi = v);
                            widget.onRoi(v);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
""",
    """                Row(
                  children: [25.0, 35.0, 50.0].map((v) {
                    final selected = (roi - v).abs() < 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Center(child: Text(v == 25 ? t('Locker', 'Light') : v == 35 ? t('Standard', 'Standard') : t('Hoch', 'High'))),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => roi = v);
                            widget.onRoi(v);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(t('Mindestgewinn pro Flip', 'Minimum profit per flip'), style: const TextStyle(fontWeight: FontWeight.w900))),
                    Text(euro(minProfit), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4B4CB8))),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [10.0, 20.0, 30.0, 50.0].map((v) => ChoiceChip(
                    label: Text(euro(v)),
                    selected: (minProfit - v).abs() < .5,
                    onSelected: (_) {
                      setState(() => minProfit = v);
                      widget.onMinProfit?.call(v);
                    },
                  )).toList(),
                ),
""",
)

# More concrete but honest premium positioning. Billing is deliberately not faked.
replace_once(
    'lib/v07_settings.dart',
    """                Text(english ? 'No ads · more checks · price alerts' : 'Keine Werbung · mehr Checks · Preisalarme', style: const TextStyle(color: Color(0xFFD3D3EE), fontSize: 12)),
""",
    """                Text(english ? 'No ads · advanced market data · price alerts' : 'Keine Werbung · erweiterte Marktdaten · Preisalarme', style: const TextStyle(color: Color(0xFFD3D3EE), fontSize: 12)),
                if (!active) ...[
                  const SizedBox(height: 4),
                  Text(english ? 'Planned: €7.99/month · €59.99/year' : 'Geplant: 7,99 €/Monat · 59,99 €/Jahr', style: const TextStyle(color: Color(0xFFBFC0DF), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
""",
)

# Tests follow the actual user priority and guard the new min-profit rule.
replace_once(
    'test/v10_flow_test.dart',
    """  testWidgets('V0.10 starts directly with scan and search actions', (tester) async {
    await tester.pumpWidget(const FlipRadarV10App());
    await tester.pumpAndSettle();

    expect(find.text('Lohnt sich das?'), findsOneWidget);
    expect(find.text('JETZT SCANNEN'), findsOneWidget);
    expect(find.text('Produkt, Modell oder EAN suchen'), findsOneWidget);
    expect(find.text('Meine Flips'), findsOneWidget);
  });
""",
    """  testWidgets('V0.12 starts search-first and keeps barcode secondary', (tester) async {
    await tester.pumpWidget(const FlipRadarV10App());
    await tester.pumpAndSettle();

    expect(find.text('Was willst du flippen?'), findsOneWidget);
    expect(find.text('FLIP PRÜFEN'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('JETZT SCANNEN'), findsNothing);
    expect(find.byKey(const ValueKey('home-search-field')), findsOneWidget);
    expect(find.text('Meine Flips'), findsOneWidget);
  });
""",
)
replace_once(
    'test/v10_flow_test.dart',
    """    expect(find.text('NÄCHSTEN ARTIKEL SCANNEN'), findsOneWidget);
""",
    """    expect(find.text('NEUE SUCHE'), findsOneWidget);
    expect(find.text('FLIP-DATEN'), findsOneWidget);
""",
)
replace_once(
    'test/v10_flow_test.dart',
    """  testWidgets('V0.11 shows comparison portals before Details is opened', (tester) async {
""",
    """  testWidgets('V0.12 minimum profit can be stricter than ROI alone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FastCheckPage(
          english: false,
          initialQuery: 'Testgerät',
          targetRoi: 10,
          minProfit: 20,
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
    await tester.enterText(fields.at(1), '80');
    await tester.enterText(find.byKey(const ValueKey('manual-sale-price-input')), '100');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('commit-manual-sale-price')));
    await tester.pump();

    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('80 €'), findsWidgets);
    expect(find.textContaining('mind. 20 € Gewinn'), findsWidgets);
  });

  testWidgets('V0.11 shows comparison portals before Details is opened', (tester) async {
""",
)
replace_once(
    'test/v10_flow_test.dart',
    """    expect(find.text('WO WILLST DU VERGLEICHEN?'), findsOneWidget);
""",
    """    expect(find.text('FLIP-DATEN'), findsOneWidget);
    expect(find.textContaining('Verkaufstempo/Sell-through'), findsOneWidget);
    expect(find.text('WO WILLST DU VERGLEICHEN?'), findsOneWidget);
""",
)

print('FlipRadar V0.12 search-first patch applied.')
