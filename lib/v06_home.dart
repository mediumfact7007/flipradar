part of 'v06.dart';

class HomePage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<FlipItem> flips;
  final List<WatchItem> watchlist;
  final List<String> history;
  final List<PriceSource> sources;
  final ValueChanged<String> onCheck;
  final VoidCallback onScan;
  final VoidCallback onSources;

  const HomePage({
    super.key,
    required this.english,
    required this.plan,
    required this.flips,
    required this.watchlist,
    required this.history,
    required this.sources,
    required this.onCheck,
    required this.onScan,
    required this.onSources,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  String t(String de, String en) => widget.english ? en : de;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((e) => e.status == 'Sold');
    final profit = sold.fold<double>(0, (a, b) => a + b.profit);
    final activeSources = widget.sources.where((e) => e.enabled).length;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(child: header('FlipRadar', t('In Sekunden wissen, ob sich ein Deal lohnt.', 'Know in seconds whether a deal is worth it.'))),
            planChip(widget.plan),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: widget.onScan,
                    icon: const Icon(Icons.qr_code_scanner, size: 26),
                    label: Text(t('Barcode scannen', 'Scan barcode'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(t('oder', 'or'), style: const TextStyle(color: Colors.black45)),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) widget.onCheck(v.trim());
                  },
                  decoration: InputDecoration(
                    hintText: t('Produktname, Modell, EAN oder ASIN', 'Product, model, EAN or ASIN'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        if (search.text.trim().isNotEmpty) widget.onCheck(search.text.trim());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: smallMetric(t('Gewinn', 'Profit'), '${profit.toStringAsFixed(0)} €', Icons.trending_up)),
            const SizedBox(width: 8),
            Expanded(child: smallMetric(t('Merkliste', 'Watch'), '${widget.watchlist.length}', Icons.bookmark_outline)),
            const SizedBox(width: 8),
            Expanded(child: smallMetric(t('Quellen', 'Sources'), '$activeSources', Icons.hub_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onSources,
          child: infoBox(
            context,
            activeSources > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            activeSources > 0
                ? t('$activeSources Preisquellen sind bereit. Tippe hier zum Ändern.', '$activeSources price sources are ready. Tap to change.')
                : t('Noch keine Preisquelle aktiv. Tippe hier zum Einrichten.', 'No price source enabled yet. Tap here to set up.'),
          ),
        ),
        if (widget.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          sectionTitle(context, t('Zuletzt geprüft', 'Recently checked')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.history.take(6).map((q) => ActionChip(
              avatar: const Icon(Icons.history, size: 18),
              label: Text(q, overflow: TextOverflow.ellipsis),
              onPressed: () => widget.onCheck(q),
            )).toList(),
          ),
        ],
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 18),
          SponsoredCard(
            english: widget.english,
            messageDe: 'Passender Partnerplatz – ruhig zwischen Inhalten, nie mitten in der Kaufentscheidung.',
            messageEn: 'Relevant partner placement – calmly between content, never inside the buying decision.',
          ),
        ],
        const SizedBox(height: 18),
        sectionTitle(context, t('So einfach geht’s', 'How it works')),
        const SizedBox(height: 8),
        howRow('1', Icons.qr_code_scanner, t('Scannen oder suchen', 'Scan or search'), t('Ein Name oder Barcode reicht.', 'A name or barcode is enough.')),
        howRow('2', Icons.compare_arrows, t('Preise bündeln', 'Compare prices'), t('Live-Daten und offizielle Suchen an einem Ort.', 'Live data and official searches in one place.')),
        howRow('3', Icons.thumb_up_alt_outlined, t('Entscheiden', 'Decide'), t('BUY MAX und klare Ampel statt Zahlenchaos.', 'BUY MAX and a clear signal instead of number overload.')),
      ],
    );
  }
}
