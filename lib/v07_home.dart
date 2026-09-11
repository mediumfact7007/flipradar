part of 'v07.dart';

class HomePage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<FlipItem> flips;
  final List<WatchItem> watchlist;
  final List<String> history;
  final List<PriceSource> sources;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  const HomePage({
    super.key,
    required this.english,
    required this.plan,
    required this.flips,
    required this.watchlist,
    required this.history,
    required this.sources,
    required this.onSearch,
    required this.onScan,
    required this.onSettings,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final query = TextEditingController();
  String t(String de, String en) => widget.english ? en : de;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void submit() {
    final q = query.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final openFlips = widget.flips.where((f) => f.status != 'Sold').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FlipRadar',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7),
              ),
            ),
            IconButton.filledTonal(
              tooltip: t('Einstellungen', 'Settings'),
              onPressed: widget.onSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF202044), Color(0xFF5B5CE2)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x2024234B), blurRadius: 28, offset: Offset(0, 13)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Lohnt sich der Deal?', 'Is the deal worth it?'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                t('Artikel prüfen. Preis eingeben. Entscheidung bekommen.', 'Check item. Enter price. Get a decision.'),
                style: const TextStyle(color: Color(0xFFDADAF3), fontSize: 14.5, height: 1.3),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF292853),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: widget.onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 23),
                  label: Text(t('BARCODE SCANNEN', 'SCAN BARCODE')),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: query,
                onSubmitted: (_) => submit(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t('Oder Produkt suchen', 'Or search product'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: submit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9EAF1)),
          ),
          child: Row(
            children: [
              _FlowStep(number: '1', label: t('Scannen', 'Scan')),
              const _FlowArrow(),
              _FlowStep(number: '2', label: t('Preis', 'Price')),
              const _FlowArrow(),
              _FlowStep(number: '3', label: t('Entscheidung', 'Decision')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF7FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.ios_share_rounded, color: Color(0xFF2D6FA4), size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('Online gefunden? Teilen → FlipRadar', 'Found online? Share → FlipRadar'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF315F83)),
                ),
              ),
            ],
          ),
        ),
        if (widget.history.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(t('Nochmal prüfen', 'Check again'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.history.take(4).map((q) {
              return ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16),
                label: Text(q, overflow: TextOverflow.ellipsis),
                onPressed: () => widget.onSearch(q),
              );
            }).toList(),
          ),
        ],
        if (widget.watchlist.isNotEmpty || openFlips > 0) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                Expanded(
                  child: _CompactStat(
                    icon: Icons.bookmark_rounded,
                    value: '${widget.watchlist.length}',
                    label: t('gemerkt', 'saved'),
                  ),
                ),
                Container(width: 1, height: 38, color: const Color(0xFFE8E9EF)),
                Expanded(
                  child: _CompactStat(
                    icon: Icons.inventory_2_rounded,
                    value: '$openFlips',
                    label: t('offen', 'open'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 24),
          SponsoredSlot(english: widget.english, placement: 'home_tail'),
        ],
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String number;
  final String label;

  const _FlowStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDFC),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4E4FBA))),
          ),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B3BE), size: 20),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CompactStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF5B5CE2)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF7B7F8D)))),
      ],
    );
  }
}
