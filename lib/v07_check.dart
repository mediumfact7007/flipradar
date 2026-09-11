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

  double parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

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
      if (_resaleValues(all).isEmpty) showManual = true;
    });
  }

  List<double> _resaleValues([List<SourceListing>? input]) =>
      (input ?? listings)
          .where((e) => e.role == 'resale' || e.role == 'local')
          .map((e) => e.total)
          .where((v) => v > 0)
          .toList();

  List<double> _retailValues() => listings
      .where((e) => e.role == 'retail' || e.role == 'refurb')
      .map((e) => e.total)
      .where((v) => v > 0)
      .toList();

  List<double> _buybackValues() => listings
      .where((e) => e.role == 'buyback')
      .map((e) => e.total)
      .where((v) => v > 0)
      .toList();

  List<double> _clean(List<double> raw) {
    final values = [...raw]..sort();
    if (values.length < 5) return values;
    final base = _median(values);
    if (base == null || base <= 0) return values;
    final filtered = values.where((v) => v >= base * 0.6 && v <= base * 1.6).toList();
    return filtered.length >= 3 ? filtered : values;
  }

  double? _median(List<double> raw) {
    if (raw.isEmpty) return null;
    final values = [...raw]..sort();
    final mid = values.length ~/ 2;
    return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
  }

  double? get resaleMedian => _median(_clean(_resaleValues()));
  double? get retailMedian => _median(_clean(_retailValues()));
  double? get buybackMedian => _median(_clean(_buybackValues()));

  double? get targetSell {
    final manual = parse(manualSell);
    if (manual > 0) return manual;
    final resale = resaleMedian;
    if (resale == null) return null;
    // Active asking prices are not sold prices. A visible 10% safety discount
    // keeps beginner decisions more conservative until sold comps are available.
    return resale * 0.90;
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

  int get confidenceLevel {
    final values = _clean(_resaleValues());
    final med = _median(values);
    if (values.isEmpty || med == null || med <= 0) return 0;
    final spread = (values.last - values.first) / med;
    if (values.length >= 8 && spread <= 0.30) return 3;
    if (values.length >= 4 && spread <= 0.60) return 2;
    return 1;
  }

  String get confidenceText {
    switch (confidenceLevel) {
      case 3:
        return t('gut', 'good');
      case 2:
        return t('okay', 'fair');
      case 1:
        return t('unsicher', 'low');
      default:
        return t('keine', 'none');
    }
  }

  double? get negotiationOffer {
    final max = maxBuy;
    final asking = parse(buy);
    if (max == null || max <= 0 || asking <= max) return null;
    final raw = math.min(max * 0.97, asking * 0.90);
    final rounded = (raw / 5).floor() * 5.0;
    return math.max(5, rounded);
  }

  List<String> get riskTips {
    final q = query.text.toLowerCase();
    if (q.contains('iphone') || q.contains('smartphone') || q.contains('galaxy') || q.contains('pixel')) {
      return widget.english
          ? ['Activation/iCloud lock', 'IMEI & network status', 'Battery, cameras & display']
          : ['iCloud-/Aktivierungssperre', 'IMEI & Netz prüfen', 'Akku, Kameras & Display'];
    }
    if (q.contains('macbook') || q.contains('laptop') || q.contains('notebook')) {
      return widget.english
          ? ['Battery condition', 'MDM/BIOS lock', 'Display, ports & charger']
          : ['Akkuzustand', 'MDM-/BIOS-Sperre', 'Display, Anschlüsse & Netzteil'];
    }
    if (q.contains('ps5') || q.contains('playstation') || q.contains('xbox') || q.contains('switch')) {
      return widget.english
          ? ['HDMI/disc drive', 'Controller & ports', 'Account/console ban']
          : ['HDMI/Laufwerk', 'Controller & Anschlüsse', 'Account-/Konsolen-Ban'];
    }
    if (q.contains('sneaker') || q.contains('jordan') || q.contains('yeezy') || q.contains('dunk')) {
      return widget.english
          ? ['Authenticity', 'Exact size/model', 'Soles, stains & wear']
          : ['Echtheit', 'Exakte Größe/Variante', 'Sohle, Flecken & Verschleiß'];
    }
    if (q.contains('kamera') || q.contains('camera') || q.contains('canon') || q.contains('nikon') || q.contains('sony alpha')) {
      return widget.english
          ? ['Sensor/lens condition', 'Shutter count', 'Battery & charger']
          : ['Sensor/Objektiv', 'Auslösungen', 'Akku & Ladegerät'];
    }
    return widget.english
        ? ['Exact model/variant', 'Defects & missing parts', 'Serial/authenticity if relevant']
        : ['Exaktes Modell/Variante', 'Defekte & fehlendes Zubehör', 'Seriennummer/Echtheit falls relevant'];
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
      SnackBar(content: Text(t('Gemerkte Deals findest du unten in der Merkliste.', 'Saved to your list.'))),
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

  Future<void> _copyNegotiation() async {
    final offer = negotiationOffer;
    if (offer == null) return;
    final q = query.text.trim();
    final text = widget.english
        ? 'Hi, would ${euro(offer)} work for $q? I could buy it soon.'
        : 'Hallo, wären ${euro(offer)} für $q okay? Ich könnte zeitnah kaufen bzw. abholen.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Nachricht kopiert.', 'Message copied.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((s) => s.enabled).toList();
    final resale = resaleMedian;
    final retail = retailMedian;
    final max = maxBuy;
    final p = profit;
    final r = roi;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Deal prüfen', 'Check deal'), style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          _StepCard(
            number: '1',
            title: t('Artikel', 'Item'),
            color: const Color(0xFFEDEDFC),
            child: Column(
              children: [
                TextField(
                  controller: query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: t('Modell, Produktname oder EAN', 'Model, product or EAN'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: loading ? null : _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 9),
                  const LinearProgressIndicator(minHeight: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _StepCard(
            number: '2',
            title: t('Dein Preis', 'Your price'),
            color: const Color(0xFFFFF3D9),
            child: TextField(
              controller: buy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '0,00',
                suffixText: '€',
                prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),
              ),
            ),
          ),
          if (searched) ...[
            const SizedBox(height: 12),
            if (resale != null && parse(manualSell) <= 0)
              _MarketFoundCard(
                english: widget.english,
                askingMedian: resale,
                conservativeSell: resale * 0.90,
                count: _clean(_resaleValues()).length,
                confidenceLevel: confidenceLevel,
              )
            else if (retail != null && parse(manualSell) <= 0)
              _RetailReferenceCard(
                english: widget.english,
                retailMedian: retail,
                onManual: () => setState(() => showManual = true),
              )
            else if (parse(manualSell) <= 0)
              _NoLiveDataCard(
                english: widget.english,
                sources: enabled,
                onOpenSource: _openSource,
                onManual: () => setState(() => showManual = true),
              ),
            if (resale != null && parse(manualSell) <= 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => showManual = !showManual),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(t('Eigenen Verkaufspreis nutzen', 'Use your own sale price')),
                ),
              ),
            ],
            if (showManual || (parse(manualSell) > 0)) ...[
              const SizedBox(height: 6),
              TextField(
                controller: manualSell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: resale == null ? 'z. B. 250' : euro(resale * 0.90),
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
              confidenceLevel: confidenceLevel,
            ),
            if ((decision == _DealDecision.negotiate || decision == _DealDecision.skip) && negotiationOffer != null) ...[
              const SizedBox(height: 10),
              _NegotiationCard(
                english: widget.english,
                offer: negotiationOffer!,
                onCopy: _copyNegotiation,
              ),
            ],
            if (decision == _DealDecision.buy || decision == _DealDecision.negotiate) ...[
              const SizedBox(height: 10),
              _RiskCard(english: widget.english, tips: riskTips),
            ],
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
                  const SizedBox(width: 9),
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
            if (decision == _DealDecision.buy) ...[
              const SizedBox(height: 10),
              _SellRouteCard(english: widget.english),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(t('Warum diese Empfehlung?', 'Why this recommendation?'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(t('Berechnung und Daten nur bei Bedarf', 'Calculation and data only if needed'), style: const TextStyle(fontSize: 12)),
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
                  resaleMedian: resale,
                  retailMedian: retail,
                  buybackMedian: buybackMedian,
                  targetRoi: widget.targetRoi,
                  costs: parse(costs),
                  confidence: confidenceText,
                  manualPrice: parse(manualSell) > 0,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t(
                      parse(manualSell) > 0
                          ? 'Die Entscheidung nutzt deinen eigenen Verkaufspreis.'
                          : 'Aktive Wiederverkaufsangebote sind keine echten Verkäufe. Deshalb zieht FlipRadar 10 % Sicherheitsabstand vom Angebots-Median ab.',
                      parse(manualSell) > 0
                          ? 'The decision uses your own sale price.'
                          : 'Active resale listings are not sold prices. FlipRadar therefore applies a 10% safety discount to the asking-price median.',
                    ),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF747987), height: 1.4),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(t('Preise & Quellen', 'Prices & sources'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                listings.isEmpty
                    ? t('${enabled.length} Webseiten verfügbar', '${enabled.length} websites available')
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
                        subtitle: Text('${item.sourceName} · ${_roleLabel(item.role)}${item.condition.isEmpty ? '' : ' · ${item.condition}'}'),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF276AA5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('Artikel suchen → Preis eingeben → Entscheidung.', 'Search item → enter price → get decision.'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF315B7E), fontWeight: FontWeight.w800),
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

  String _roleLabel(String role) {
    switch (role) {
      case 'resale':
        return t('Wiederverkauf', 'resale');
      case 'local':
        return t('lokal', 'local');
      case 'retail':
        return t('Neupreis', 'retail');
      case 'refurb':
        return t('refurbished', 'refurbished');
      case 'buyback':
        return t('Sofort-Ankauf', 'buyback');
      default:
        return t('Referenz', 'reference');
    }
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
      padding: const EdgeInsets.all(15),
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
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _MarketFoundCard extends StatelessWidget {
  final bool english;
  final double askingMedian;
  final double conservativeSell;
  final int count;
  final int confidenceLevel;

  const _MarketFoundCard({
    required this.english,
    required this.askingMedian,
    required this.conservativeSell,
    required this.count,
    required this.confidenceLevel,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F2),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFC9EEDF)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.show_chart_rounded, color: Color(0xFF0A8F6A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Konservativer Verkauf', 'Conservative sale'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF4C7568))),
                Text(euro(conservativeSell), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF145E49))),
                Text(t('Angebots-Median ${euro(askingMedian)}', 'Asking median ${euro(askingMedian)}'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF66867B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ConfidenceDots(level: confidenceLevel),
              const SizedBox(height: 4),
              Text(t('$count Vergleiche', '$count comps'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF5A756C))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RetailReferenceCard extends StatelessWidget {
  final bool english;
  final double retailMedian;
  final VoidCallback onManual;

  const _RetailReferenceCard({required this.english, required this.retailMedian, required this.onManual});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.new_releases_outlined, color: Color(0xFFAE6D00)),
              const SizedBox(width: 9),
              Expanded(child: Text(t('Neupreis gefunden: ${euro(retailMedian)}', 'Retail reference: ${euro(retailMedian)}'), style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            t('Nicht als Wiederverkaufswert benutzt. Gib einen realistischen Verkaufspreis ein.', 'Not used as resale value. Enter a realistic sale price.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF775B2A)),
          ),
          const SizedBox(height: 7),
          TextButton.icon(onPressed: onManual, icon: const Icon(Icons.edit_outlined), label: Text(t('Verkaufspreis eingeben', 'Enter sale price'))),
        ],
      ),
    );
  }
}

class _NoLiveDataCard extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<PriceSource> onOpenSource;
  final VoidCallback onManual;

  const _NoLiveDataCard({
    required this.english,
    required this.sources,
    required this.onOpenSource,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: Color(0xFF596171)),
              const SizedBox(width: 9),
              Expanded(child: Text(t('Noch kein Wiederverkaufswert', 'No resale value yet'), style: const TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 6),
          Text(t('Webseite prüfen oder Verkaufspreis selbst eingeben.', 'Check a website or enter a sale price.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF6F7482))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sources.take(4).map((s) => SourcePillButton(source: s, onTap: () => onOpenSource(s))).toList(),
          ),
          const SizedBox(height: 7),
          TextButton.icon(onPressed: onManual, icon: const Icon(Icons.edit_outlined), label: Text(t('Verkaufspreis eingeben', 'Enter sale price'))),
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
  final int confidenceLevel;

  const _DecisionCard({
    required this.english,
    required this.decision,
    required this.maxBuy,
    required this.sell,
    required this.profit,
    required this.roi,
    required this.targetRoi,
    required this.confidenceLevel,
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
        subtitle = t('Passt zu deinem Gewinnziel.', 'Fits your profit target.');
        break;
      case _DealDecision.negotiate:
        bg = const Color(0xFFFFE9B8);
        fg = const Color(0xFF684A00);
        icon = Icons.handshake_outlined;
        title = t('VERHANDELN', 'NEGOTIATE');
        subtitle = t('Fast gut. Preis runterhandeln.', 'Almost good. Negotiate it down.');
        break;
      case _DealDecision.skip:
        bg = const Color(0xFFFFE4E1);
        fg = const Color(0xFF8D2F28);
        icon = Icons.block_rounded;
        title = t('LASSEN', 'SKIP');
        subtitle = t('Zu teuer für dein Ziel.', 'Too expensive for your target.');
        break;
      case _DealDecision.waiting:
        bg = const Color(0xFFEDEDFC);
        fg = const Color(0xFF3F3F79);
        icon = Icons.arrow_upward_rounded;
        title = sell == null ? t('MARKTWERT FEHLT', 'NEED MARKET VALUE') : t('PREIS EINGEBEN', 'ENTER PRICE');
        subtitle = sell == null
            ? t('Verkaufspreis ergänzen oder Quelle prüfen.', 'Add sale price or check a source.')
            : t('Dann kommt sofort die Entscheidung.', 'Then you get the decision instantly.');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(27)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: decision == _DealDecision.buy ? 0.12 : 0.65), borderRadius: BorderRadius.circular(17)),
                child: Icon(icon, color: fg, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: fg, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.82), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          if (maxBuy != null && sell != null) ...[
            const SizedBox(height: 17),
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
                        Text(euro(maxBuy!), style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: Color(0xFF20222A), letterSpacing: -1)),
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
                        Text(t('Verkauf ca.', 'Sale est.'), style: const TextStyle(fontSize: 11, color: Color(0xFF7A7E8C))),
                        Text(euro(sell!), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (profit != null && roi != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: _MiniResult(label: t('Gewinn ca.', 'Profit est.'), value: euro(profit!), color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniResult(label: 'ROI', value: '${roi!.toStringAsFixed(0)} %', color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniResult(label: t('Daten', 'Data'), value: _confidenceWord(english, confidenceLevel), color: fg)),
                ],
              ),
            ],
          ],
          const SizedBox(height: 8),
          Text(t('Schätzung, keine Garantie.', 'Estimate, not a guarantee.'), style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.58))),
        ],
      ),
    );
  }

  static String _confidenceWord(bool english, int level) {
    if (level >= 3) return english ? 'good' : 'gut';
    if (level == 2) return english ? 'fair' : 'okay';
    return english ? 'low' : 'wenig';
  }
}

class _NegotiationCard extends StatelessWidget {
  final bool english;
  final double offer;
  final VoidCallback onCopy;

  const _NegotiationCard({required this.english, required this.offer, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF5DD), borderRadius: BorderRadius.circular(21)),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF9C6500)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Versuch ${euro(offer)}', 'Try ${euro(offer)}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                Text(t('FlipRadar formuliert dir eine kurze Anfrage.', 'FlipRadar prepares a short offer message.'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF775B2A))),
              ],
            ),
          ),
          TextButton(onPressed: onCopy, child: Text(t('Kopieren', 'Copy'))),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final bool english;
  final List<String> tips;

  const _RiskCard({required this.english, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE8E9EF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 21, color: Color(0xFF5B5CE2)),
              const SizedBox(width: 8),
              Text(english ? 'Before you buy' : 'Vor Kauf kurz prüfen', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          ...tips.take(3).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 17, color: Color(0xFF0A8F6A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SellRouteCard extends StatelessWidget {
  final bool english;

  const _SellRouteCard({required this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(21)),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, color: Color(0xFF2D6FA4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              english ? 'After buying: eBay = reach · Kleinanzeigen = local pickup' : 'Danach: eBay = Reichweite · Kleinanzeigen = lokal/Abholung',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF315F83)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceDots extends StatelessWidget {
  final int level;

  const _ConfidenceDots({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i < level;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF0A8F6A) : const Color(0xFFC7D8D2),
          ),
        );
      }),
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
  final double? resaleMedian;
  final double? retailMedian;
  final double? buybackMedian;
  final double targetRoi;
  final double costs;
  final String confidence;
  final bool manualPrice;

  const _DetailsGrid({
    required this.english,
    required this.resaleMedian,
    required this.retailMedian,
    required this.buybackMedian,
    required this.targetRoi,
    required this.costs,
    required this.confidence,
    required this.manualPrice,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Wiederverkauf', 'Resale asking'), value: resaleMedian == null ? '–' : euro(resaleMedian!))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Datenlage', 'Confidence'), value: confidence)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Neupreis', 'Retail'), value: retailMedian == null ? '–' : euro(retailMedian!))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Sofort-Ankauf', 'Buyback'), value: buybackMedian == null ? '–' : euro(buybackMedian!))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Zusatzkosten', 'Extra costs'), value: euro(costs))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Gewinnziel', 'Target ROI'), value: '${targetRoi.toStringAsFixed(0)} %')),
          ],
        ),
      ],
    );
  }
}
