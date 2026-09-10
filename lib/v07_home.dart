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
    final activeSources = widget.sources.where((s) => s.enabled).length;
    final sold = widget.flips.where((f) => f.status == 'Sold').toList();
    final profit = sold.fold<double>(0, (a, b) => a + b.profit);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        screenHeader(
          context,
          title: 'FlipRadar',
          subtitle: t('In Sekunden wissen, ob sich ein Kauf lohnt.', 'Know in seconds if a deal is worth it.'),
          trailing: IconButton.filledTonal(
            tooltip: t('Einstellungen', 'Settings'),
            onPressed: widget.onSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF24234B), Color(0xFF5B5CE2)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Color(0x1F24234B), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Ist das ein guter Deal?', 'Is this a good deal?'),
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7),
              ),
              const SizedBox(height: 6),
              Text(
                t('Scannen oder suchen → maximalen Kaufpreis sehen.', 'Scan or search → see your maximum buy price.'),
                style: const TextStyle(color: Color(0xFFD9D9F5), fontSize: 14.5, height: 1.35),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D2C5A),
                  ),
                  onPressed: widget.onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(t('BARCODE SCANNEN', 'SCAN BARCODE')),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0x55FFFFFF))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(t('oder', 'or'), style: const TextStyle(color: Color(0xFFCBCBE7), fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: Color(0x55FFFFFF))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: query,
                onSubmitted: (_) => submit(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t('Produktname oder EAN', 'Product name or EAN'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(onPressed: submit, icon: const Icon(Icons.arrow_forward_rounded)),
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroFact(icon: Icons.payments_outlined, text: t('Maximal zahlen', 'Max buy')),
                  _HeroFact(icon: Icons.trending_up, text: t('Gewinn', 'Profit')),
                  _HeroFact(icon: Icons.storefront_outlined, text: t('$activeSources Quellen', '$activeSources sources')),
                ],
              ),
            ],
          ),
        ),
        if (widget.history.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Text(t('Zuletzt geprüft', 'Recent checks'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(t('Tippen zum Wiederholen', 'Tap to repeat'), style: const TextStyle(fontSize: 11, color: Color(0xFF8A8E9C))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.history.take(6).map((q) {
              return ActionChip(
                avatar: const Icon(Icons.history, size: 16),
                label: Text(q, overflow: TextOverflow.ellipsis),
                onPressed: () => widget.onSearch(q),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _QuickInfoCard(
                icon: Icons.bookmark_rounded,
                iconColor: const Color(0xFF5B5CE2),
                background: const Color(0xFFEDEDFC),
                value: '${widget.watchlist.length}',
                label: t('gemerkt', 'saved'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickInfoCard(
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFF0A8F6A),
                background: const Color(0xFFE6F7F1),
                value: '${widget.flips.where((f) => f.status != 'Sold').length}',
                label: t('offene Flips', 'open flips'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickInfoCard(
                icon: Icons.euro_rounded,
                iconColor: const Color(0xFFC77A00),
                background: const Color(0xFFFFF3DA),
                value: euro(profit),
                label: t('Gewinn', 'profit'),
              ),
            ),
          ],
        ),
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 22),
          SponsoredSlot(english: widget.english, placement: 'home'),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE4A8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFB46D00)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('So benutzt du FlipRadar', 'How to use FlipRadar'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      t('Preis des Artikels eingeben. Liegt er unter „Maximal zahlen“, ist der Deal für dein Ziel interessant.', 'Enter the item price. If it is below “Max buy”, the deal fits your target.'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF71551E), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String value;
  final String label;

  const _QuickInfoCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF6D7180))),
        ],
      ),
    );
  }
}
