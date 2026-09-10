part of 'v07.dart';

enum _DealDecision { waiting, buy, negotiate, skip }

class CheckPage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<FlipItem> onAddFlip;

  const CheckPage({
    super.key,
    required this.english,
    required this.initialQuery,
    required this.targetRoi,
    required this.plan,
    required this.sources,
    required this.onHistory,
    required this.onWatch,
    required this.onAddFlip,
  });

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '0');
  bool loading = false;
  bool searched = false;
  bool showManual = false;
  bool showCosts = false;
  List<SourceListing> listings = [];

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    query.dispose();
    buy.dispose();
    manualSell.dispose();
    costs.dispose();
    super.dispose();
  }

  double parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty || loading) return;
    FocusScope.of(context).unfocus();
    widget.onHistory(q);
    setState(() {
      loading = true;
      searched = true;
      listings = [];
    });

    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    final batches = await Future.wait(
      direct.map((source) async {
        try {
          return await SourceRegistry.fetch(source, q);
        } catch (_) {
          return <SourceListing>[];
        }
      }),
    );

    if (!mounted) return;
    final all = batches.expand((x) => x).where((e) => e.total > 0).toList()
      ..sort((a, b) => a.total.compareTo(b.total));
    setState(() {
      listings = all;
      loading = false;
      if (all.isEmpty) showManual = true;
    });
  }

  double? get marketMedian {
    final values = listings.map((e) => e.total).where((v) => v > 0).toList()..sort();
    if (values.isEmpty) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
  }

  double? get targetSell {
    final manual = parse(manualSell);
    if (manual > 0) return manual;
    return marketMedian;
  }

  double? get maxBuy {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    return math.max(0, (sell - parse(costs)) / (1 + widget.targetRoi / 100));
  }

  double? get profit {
    final sell = targetSell;
    final price = parse(buy);
    if (sell == null || price <= 0) return null;
    return sell - price - parse(costs);
  }

  double? get roi {
    final p = profit;
    final price = parse(buy);
    if (p == null || price <= 0) return null;
    return p / price * 100;
  }

  _DealDecision get decision {
    final max = maxBuy;
    final price = parse(buy);
    if (max == null || price <= 0) return _DealDecision.waiting;
    if (price <= max) return _DealDecision.buy;
    if (price <= max * 1.15) return _DealDecision.negotiate;
    return _DealDecision.skip;
  }

  String get confidence {
    if (listings.length >= 8) return t('gut', 'good');
    if (listings.length >= 3) return t('mittel', 'medium');
    return t('niedrig', 'low');
  }

  Future<void> _openSource(PriceSource source) async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    final uri = Uri.parse(source.searchUrl(q));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openListing(SourceListing item) async {
    if (item.url.trim().isEmpty) return;
    final uri = Uri.tryParse(item.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _saveWatch() {
    final q = query.text.trim();
    if (q.isEmpty) return;
    widget.onWatch(WatchItem(query: q, maxBuy: maxBuy ?? 0, createdAt: DateTime.now()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Auf Merkliste gespeichert.', 'Saved.'))),
    );
  }

  void _saveFlip() {
    final q = query.text.trim();
    final sell = targetSell;
    final price = parse(buy);
    if (q.isEmpty || sell == null || price <= 0) return;
    widget.onAddFlip(
      FlipItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: q,
        buy: price,
        sell: sell,
        costs: parse(costs),
        status: 'Bought',
        source: 'FlipRadar',
        createdAt: DateTime.now(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Als gekauft gespeichert.', 'Saved as bought.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((s) => s.enabled).toList();
    final median = marketMedian;
    final max = maxBuy;
    final p = profit;
    final r = roi;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Deal prüfen', 'Check deal'), style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _StepCard(
            number: '1',
            title: t('Welcher Artikel?', 'Which item?'),
            color: const Color(0xFFEDEDFC),
            child: Column(
              children: [
                TextField(
                  controller: query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: t('Produktname, Modell oder EAN', 'Product, model or EAN'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(onPressed: loading ? null : _search, icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: '2',
            title: t('Was kostet er?', 'What does it cost?'),
            color: const Color(0xFFFFF3D9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: buy,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    suffixText: '€',
                    prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('Preis, den du jetzt zahlen würdest.', 'The price you would pay now.'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7D6841)),
                ),
              ],
            ),
          ),
          if (searched) ...[
            const SizedBox(height: 12),
            if (median == null)
              _NoLiveDataCard(
                english: widget.english,
                sources: enabled,
                onOpenSource: _openSource,
                showManual: showManual,
                onToggleManual: () => setState(() => showManual = !showManual),
                manualSell: manualSell,
                onManualChanged: () => setState(() {}),
              ),
            if (median != null && parse(manualSell) <= 0)
              _MarketFoundCard(
                english: widget.english,
                median: median,
                count: listings.length,
                confidence: confidence,
              ),
            if (median != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => showManual = !showManual),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t('Verkaufspreis selbst festlegen', 'Set sale price yourself')),
              ),
            ],
            if (showManual && (median != null || listings.isEmpty)) ...[
              const SizedBox(height: 8),
              TextField(
                controller: manualSell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: median == null ? 'z. B. 250' : euro(median),
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _DecisionCard(
              english: widget.english,
              decision: decision,
              maxBuy: max,
              sell: targetSell,
              profit: p,
              roi: r,
              targetRoi: widget.targetRoi,
            ),
            if (targetSell != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveWatch,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(t('Merken', 'Save')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: parse(buy) > 0 ? _saveFlip : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(t('Gekauft', 'Bought')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.tune_rounded),
              title: Text(t('Details & Kosten', 'Details & costs'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(t('Nur wenn du genauer rechnen willst', 'Only if you want more detail'), style: const TextStyle(fontSize: 12)),
              children: [
                if (!showCosts)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => showCosts = true),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(t('Versand/Gebühren hinzufügen', 'Add shipping/fees')),
                    ),
                  ),
                if (showCosts)
                  TextField(
                    controller: costs,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                      suffixText: '€',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                const SizedBox(height: 10),
                _DetailsGrid(
                  english: widget.english,
                  listings: listings,
                  median: median,
                  targetRoi: widget.targetRoi,
                  costs: parse(costs),
                  confidence: confidence,
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(t('Preise & Quellen', 'Prices & sources'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                listings.isEmpty
                    ? t('${enabled.length} Webseiten öffnen', 'Open ${enabled.length} websites')
                    : t('${listings.length} Live-Treffer', '${listings.length} live results'),
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                if (listings.isNotEmpty)
                  ...listings.take(12).map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEDEDFC),
                          child: Text(item.sourceName.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item.sourceName}${item.condition.isEmpty ? '' : ' · ${item.condition}'}'),
                        trailing: Text(euro(item.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                        onTap: () => _openListing(item),
                      )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: enabled.take(8).map((s) => SourcePillButton(source: s, onTap: () => _openSource(s))).toList(),
                ),
              ],
            ),
            if (widget.plan == UserPlan.free) ...[
              const SizedBox(height: 14),
              SponsoredSlot(english: widget.english, placement: 'result_tail'),
            ],
          ] else ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF276AA5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('Artikel suchen. Danach zeigt FlipRadar direkt deinen maximalen Kaufpreis.', 'Search the item. FlipRadar then shows your maximum buy price.'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF315B7E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final Color color;
  final Widget child;

  const _StepCard({required this.number, required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MarketFoundCard extends StatelessWidget {
  final bool english;
  final double median;
  final int count;
  final String confidence;

  const _MarketFoundCard({required this.english, required this.median, required this.count, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9EEDF)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.analytics_outlined, color: Color(0xFF0A8F6A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(english ? 'Market estimate' : 'Markt-Schätzung', style: const TextStyle(fontSize: 12, color: Color(0xFF4C7568))),
                Text(euro(median), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF145E49))),
              ],
            ),
          ),
          TinyLabel(
            text: english ? '$count hits' : '$count Treffer',
            color: const Color(0xFF145E49),
            background: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _NoLiveDataCard extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<PriceSource> onOpenSource;
  final bool showManual;
  final VoidCallback onToggleManual;
  final TextEditingController manualSell;
  final VoidCallback onManualChanged;

  const _NoLiveDataCard({
    required this.english,
    required this.sources,
    required this.onOpenSource,
    required this.showManual,
    required this.onToggleManual,
    required this.manualSell,
    required this.onManualChanged,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: Color(0xFF596171)),
              const SizedBox(width: 9),
              Expanded(child: Text(t('Noch kein Live-Marktwert', 'No live market value yet'), style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t('Öffne eine Preisquelle oder gib deinen erwarteten Verkaufspreis ein.', 'Open a price source or enter your expected sale price.'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF6F7482)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sources.take(4).map((s) => SourcePillButton(source: s, onTap: () => onOpenSource(s))).toList(),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onToggleManual,
            icon: const Icon(Icons.edit_outlined),
            label: Text(t('Verkaufspreis eingeben', 'Enter sale price')),
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final bool english;
  final _DealDecision decision;
  final double? maxBuy;
  final double? sell;
  final double? profit;
  final double? roi;
  final double targetRoi;

  const _DecisionCard({
    required this.english,
    required this.decision,
    required this.maxBuy,
    required this.sell,
    required this.profit,
    required this.roi,
    required this.targetRoi,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    switch (decision) {
      case _DealDecision.buy:
        bg = const Color(0xFF103F35);
        fg = Colors.white;
        icon = Icons.thumb_up_alt_rounded;
        title = t('KAUFEN', 'BUY');
        subtitle = t('Der Preis liegt in deinem Zielbereich.', 'The price fits your target.');
        break;
      case _DealDecision.negotiate:
        bg = const Color(0xFFFFE9B8);
        fg = const Color(0xFF684A00);
        icon = Icons.handshake_outlined;
        title = t('VERHANDELN', 'NEGOTIATE');
        subtitle = t('Knapp zu teuer. Versuch näher an dein Limit zu kommen.', 'Slightly too expensive. Try to get closer to your limit.');
        break;
      case _DealDecision.skip:
        bg = const Color(0xFFFFE4E1);
        fg = const Color(0xFF8D2F28);
        icon = Icons.block_rounded;
        title = t('LASSEN', 'SKIP');
        subtitle = t('Für dein Gewinnziel ist der Einkauf zu teuer.', 'The buy price is too high for your profit target.');
        break;
      case _DealDecision.waiting:
        bg = const Color(0xFFEDEDFC);
        fg = const Color(0xFF3F3F79);
        icon = Icons.arrow_downward_rounded;
        title = t('PREIS EINGEBEN', 'ENTER PRICE');
        subtitle = sell == null
            ? t('Marktwert fehlt noch.', 'Market value is still missing.')
            : t('Dann bekommst du sofort eine Entscheidung.', 'Then you get an instant decision.');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: decision == _DealDecision.buy ? 0.12 : 0.65), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: fg, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.82), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          if (maxBuy != null && sell != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('MAXIMAL ZAHLEN', 'MAX BUY'), style: const TextStyle(fontSize: 11, color: Color(0xFF7A7E8C), fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(euro(maxBuy!), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF20222A), letterSpacing: -1)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 42, color: const Color(0xFFE7E8EE)),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('Verkauf', 'Sale'), style: const TextStyle(fontSize: 11, color: Color(0xFF7A7E8C))),
                        Text(euro(sell!), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (profit != null && roi != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MiniResult(label: t('Gewinn ca.', 'Profit est.'), value: euro(profit!), color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniResult(label: 'ROI', value: '${roi!.toStringAsFixed(0)} %', color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniResult(label: t('Ziel', 'Target'), value: '${targetRoi.toStringAsFixed(0)} %', color: fg)),
                ],
              ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            t('Schätzung, keine Garantie.', 'Estimate, not a guarantee.'),
            style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.58)),
          ),
        ],
      ),
    );
  }
}

class _MiniResult extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniResult({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: color == Colors.white ? 0.12 : 0.6), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color.withValues(alpha: 0.72), fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final bool english;
  final List<SourceListing> listings;
  final double? median;
  final double targetRoi;
  final double costs;
  final String confidence;

  const _DetailsGrid({
    required this.english,
    required this.listings,
    required this.median,
    required this.targetRoi,
    required this.costs,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    final min = listings.isEmpty ? null : listings.map((e) => e.total).reduce(math.min);
    final max = listings.isEmpty ? null : listings.map((e) => e.total).reduce(math.max);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Marktwert', 'Market'), value: median == null ? '–' : euro(median!))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Datenlage', 'Confidence'), value: confidence)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Preisspanne', 'Price range'), value: min == null || max == null ? '–' : '${euro(min)}–${euro(max)}')),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Zusatzkosten', 'Extra costs'), value: euro(costs))),
          ],
        ),
      ],
    );
  }
}
