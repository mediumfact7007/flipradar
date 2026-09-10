part of 'v06.dart';

class CheckPage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;

  const CheckPage({
    super.key,
    required this.english,
    required this.initialQuery,
    required this.targetRoi,
    required this.plan,
    required this.sources,
    required this.onAddFlip,
    required this.onHistory,
    required this.onWatch,
  });

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final costs = TextEditingController(text: '10');
  final manualSell = TextEditingController();
  bool loading = false;
  bool searched = false;
  List<SourceListing> listings = [];
  final Map<String, String> errors = {};

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
    costs.dispose();
    manualSell.dispose();
    super.dispose();
  }

  double parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onHistory(q);
    setState(() {
      loading = true;
      searched = true;
      listings = [];
      errors.clear();
    });

    final enabled = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    final collected = <SourceListing>[];
    await Future.wait(enabled.map((source) async {
      try {
        collected.addAll(await SourceRegistry.fetch(source, q));
      } catch (_) {
        errors[source.id] = t('Keine Live-Antwort', 'No live response');
      }
    }));

    if (!mounted) return;
    setState(() {
      listings = collected..sort((a, b) => a.total.compareTo(b.total));
      loading = false;
    });
  }

  double? get median {
    final values = listings.map((e) => e.total).where((v) => v > 0).toList()..sort();
    if (values.isEmpty) return null;
    final m = values.length ~/ 2;
    return values.length.isOdd ? values[m] : (values[m - 1] + values[m]) / 2;
  }

  double? get targetSell {
    final manual = parse(manualSell);
    return manual > 0 ? manual : median;
  }

  double? get buyMax {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    return math.max(0, (sell - parse(costs)) / (1 + widget.targetRoi / 100));
  }

  String verdict() {
    final b = parse(buy);
    final max = buyMax;
    if (max == null) return 'unknown';
    if (b <= 0) return 'price';
    if (b <= max * 0.90) return 'buy';
    if (b <= max) return 'negotiate';
    return 'skip';
  }

  Future<void> _open(PriceSource source) async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    await launchUrl(Uri.parse(source.searchUrl(q)), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((e) => e.enabled).toList();
    final m = median;
    final max = buyMax;
    final sell = targetSell;
    final buyValue = parse(buy);
    final costValue = parse(costs);
    final profit = sell == null ? null : sell - buyValue - costValue;
    final roi = profit == null || buyValue <= 0 ? null : profit / buyValue * 100;
    final signal = verdict();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Deal prüfen', 'Check a deal'), t('Ein Produkt rein. Eine klare Entscheidung raus.', 'One product in. One clear decision out.')),
        const SizedBox(height: 14),
        TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: t('Was möchtest du prüfen?', 'What do you want to check?'),
            hintText: t('Produkt, Modell, EAN oder ASIN', 'Product, model, EAN or ASIN'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : _search,
            icon: const Icon(Icons.compare_arrows),
            label: Text(loading ? t('Suche läuft…', 'Searching…') : t('Jetzt vergleichen', 'Compare now')),
          ),
        ),
        if (searched) ...[
          const SizedBox(height: 16),
          if (m != null)
            VerdictCard(
              english: widget.english,
              signal: signal,
              median: m,
              buyMax: max ?? 0,
              targetRoi: widget.targetRoi,
            )
          else
            infoBox(
              context,
              Icons.info_outline,
              t(
                'Noch keine Live-Preise direkt in der App. Nutze darunter die offiziellen Shopsuchen – sobald dein Server verbunden ist, erscheinen Live-Treffer automatisch.',
                'No live prices inside the app yet. Use the official searches below – once your server is connected, live results appear automatically.',
              ),
            ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Dein Deal', 'Your deal'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: buy,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: t('Preis vor Ort €', 'Price here €')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: costs,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: t('Kosten €', 'Costs €')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: manualSell,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t('Optional: eigener Zielverkauf €', 'Optional: your target sale €'),
                      helperText: t('Leer lassen = Marktmedian verwenden', 'Leave empty = use market median'),
                    ),
                  ),
                  if (sell != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: resultTile(t('Zielverkauf', 'Target sale'), '${sell.toStringAsFixed(0)} €')),
                        Expanded(child: resultTile('BUY MAX', max == null ? '–' : '${max.toStringAsFixed(0)} €')),
                        Expanded(child: resultTile('ROI', roi == null ? '–' : '${roi.toStringAsFixed(0)} %')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: max == null
                      ? null
                      : () {
                          widget.onWatch(WatchItem(query: query.text.trim(), maxBuy: max, createdAt: DateTime.now()));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Zur Merkliste hinzugefügt', 'Added to watchlist'))));
                        },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(t('Merken', 'Watch')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: sell == null || buyValue <= 0
                      ? null
                      : () {
                          widget.onAddFlip(FlipItem(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            name: query.text.trim(),
                            buy: buyValue,
                            sell: sell,
                            costs: costValue,
                            status: 'Bought',
                            source: listings.isEmpty ? 'Manual' : listings.first.sourceName,
                            createdAt: DateTime.now(),
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Flip gespeichert', 'Flip saved'))));
                        },
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(t('Als Flip speichern', 'Save as flip')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          sectionTitle(context, t('Preisquellen', 'Price sources')),
          const SizedBox(height: 8),
          ...enabled.map((source) {
            final hits = listings.where((x) => x.sourceId == source.id).toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: sourceBadge(source),
                title: Text(source.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  hits.isNotEmpty
                      ? t('${hits.length} Live-Treffer · ab ${hits.first.total.toStringAsFixed(2)} €', '${hits.length} live results · from ${hits.first.total.toStringAsFixed(2)} €')
                      : source.canFetchInApp
                          ? (errors[source.id] ?? t('Keine Live-Treffer · offizielle Suche öffnen', 'No live results · open official search'))
                          : t('Offizielle Live-Suche öffnen', 'Open official live search'),
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(source),
              ),
            );
          }),
          if (widget.plan == UserPlan.free) ...[
            const SizedBox(height: 10),
            SponsoredCard(
              english: widget.english,
              messageDe: 'Werbung erscheint erst nach deiner Auswertung – nicht davor und nicht über dem BUY-MAX-Ergebnis.',
              messageEn: 'Ads appear only after your result – never before it and never over the BUY MAX result.',
            ),
          ],
        ],
      ],
    );
  }
}

class VerdictCard extends StatelessWidget {
  final bool english;
  final String signal;
  final double median;
  final double buyMax;
  final double targetRoi;

  const VerdictCard({
    super.key,
    required this.english,
    required this.signal,
    required this.median,
    required this.buyMax,
    required this.targetRoi,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String text;
    Color bg;

    switch (signal) {
      case 'buy':
        icon = Icons.thumb_up_alt;
        title = t('KAUFEN', 'BUY');
        text = t('Der Preis liegt komfortabel unter deinem BUY MAX.', 'The price is comfortably below your BUY MAX.');
        bg = Colors.green.shade50;
        break;
      case 'negotiate':
        icon = Icons.handshake_outlined;
        title = t('VERHANDELN', 'NEGOTIATE');
        text = t('Der Deal kann passen, aber dein Puffer ist klein.', 'The deal can work, but your safety margin is small.');
        bg = Colors.orange.shade50;
        break;
      case 'skip':
        icon = Icons.block;
        title = t('LASSEN', 'SKIP');
        text = t('Der Einkaufspreis liegt über deinem Ziel.', 'The purchase price is above your target.');
        bg = Colors.red.shade50;
        break;
      case 'price':
        icon = Icons.euro;
        title = t('PREIS EINTRAGEN', 'ENTER PRICE');
        text = t('Was kostet der Artikel vor Ort? Dann bekommst du sofort die Ampel.', 'What does the item cost here? Then you get the decision signal instantly.');
        bg = Colors.blue.shade50;
        break;
      default:
        icon = Icons.sync;
        title = t('MARKT PRÜFEN', 'CHECK MARKET');
        text = t('Für eine sichere Ampel werden Live-Preise oder ein Zielverkauf benötigt.', 'Live prices or a target sale price are needed for a reliable signal.');
        bg = Colors.blueGrey.shade50;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.white, child: Icon(icon)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
              Chip(label: Text('BUY MAX ${buyMax.toStringAsFixed(0)} €')),
            ],
          ),
          const SizedBox(height: 8),
          Text(text),
          const SizedBox(height: 8),
          Text(
            t(
              'Marktmedian ${median.toStringAsFixed(0)} € · Ziel-ROI ${targetRoi.toStringAsFixed(0)} %',
              'Market median ${median.toStringAsFixed(0)} € · target ROI ${targetRoi.toStringAsFixed(0)}%',
            ),
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
