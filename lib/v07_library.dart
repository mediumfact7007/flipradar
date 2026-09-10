part of 'v07.dart';

class WatchlistPage extends StatelessWidget {
  final bool english;
  final UserPlan plan;
  final List<WatchItem> watchlist;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRemove;

  const WatchlistPage({
    super.key,
    required this.english,
    required this.plan,
    required this.watchlist,
    required this.onOpen,
    required this.onRemove,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        screenHeader(
          context,
          title: t('Merkliste', 'Saved'),
          subtitle: t('Interessante Deals später erneut prüfen.', 'Recheck interesting deals later.'),
        ),
        const SizedBox(height: 18),
        if (watchlist.isEmpty)
          EmptyState(
            icon: Icons.bookmark_add_outlined,
            title: t('Noch nichts gemerkt', 'Nothing saved yet'),
            text: t('Bei einem Deal auf „Merken“ tippen. Dann findest du ihn hier wieder.', 'Tap “Save” on a deal and it will appear here.'),
          )
        else ...[
          for (var i = 0; i < watchlist.length; i++) ...[
            _WatchCard(
              item: watchlist[i],
              english: english,
              onTap: () => onOpen(watchlist[i].query),
              onRemove: () => onRemove(watchlist[i].query),
            ),
            if (plan == UserPlan.free && i == 2) ...[
              const SizedBox(height: 10),
              SponsoredSlot(english: english, placement: 'watchlist'),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _WatchCard extends StatelessWidget {
  final WatchItem item;
  final bool english;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WatchCard({required this.item, required this.english, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFEDEDFC), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.bookmark_rounded, color: Color(0xFF5B5CE2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.query, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      item.maxBuy > 0
                          ? (english ? 'Your max: ${euro(item.maxBuy)}' : 'Dein Limit: ${euro(item.maxBuy)}')
                          : (english ? 'Recheck price' : 'Preis erneut prüfen'),
                      style: const TextStyle(color: Color(0xFF777B89), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 20), tooltip: english ? 'Remove' : 'Entfernen'),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8D919F)),
            ],
          ),
        ),
      ),
    );
  }
}

class FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<FlipItem> flips;
  final ValueChanged<FlipItem> onUpdate;

  const FlipsPage({
    super.key,
    required this.english,
    required this.plan,
    required this.flips,
    required this.onUpdate,
  });

  @override
  State<FlipsPage> createState() => _FlipsPageState();
}

class _FlipsPageState extends State<FlipsPage> {
  String filter = 'all';
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((f) => f.status == 'Sold').toList();
    final open = widget.flips.where((f) => f.status != 'Sold').toList();
    final profit = sold.fold<double>(0, (a, b) => a + b.profit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy);
    final shown = filter == 'sold' ? sold : filter == 'open' ? open : widget.flips;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        screenHeader(
          context,
          title: 'Flips',
          subtitle: t('Was du gekauft hast und was es gebracht hat.', 'What you bought and what it earned.'),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF202142),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(child: _DarkStat(label: t('Gewinn', 'Profit'), value: euro(profit), icon: Icons.trending_up_rounded)),
              Container(width: 1, height: 45, color: const Color(0x33FFFFFF)),
              Expanded(child: _DarkStat(label: t('Gebunden', 'Invested'), value: euro(capital), icon: Icons.account_balance_wallet_outlined)),
              Container(width: 1, height: 45, color: const Color(0x33FFFFFF)),
              Expanded(child: _DarkStat(label: t('Offen', 'Open'), value: '${open.length}', icon: Icons.inventory_2_outlined)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'all', label: Text(t('Alle', 'All'))),
            ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))),
            ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))),
          ],
          selected: {filter},
          onSelectionChanged: (v) => setState(() => filter = v.first),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: t('Noch keine Flips', 'No flips yet'),
            text: t('Bei einem Deal auf „Gekauft“ tippen. Danach kannst du Verkauf und Gewinn hier verfolgen.', 'Tap “Bought” on a deal, then track its sale and profit here.'),
          )
        else ...[
          for (var i = 0; i < shown.length; i++) ...[
            _FlipCard(item: shown[i], english: widget.english, onUpdate: widget.onUpdate),
            if (widget.plan == UserPlan.free && i == 3) ...[
              const SizedBox(height: 10),
              SponsoredSlot(english: widget.english, placement: 'flips'),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DarkStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFBFC1FF), size: 18),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
          Text(label, maxLines: 1, style: const TextStyle(color: Color(0xFFB9BBD0), fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  final FlipItem item;
  final bool english;
  final ValueChanged<FlipItem> onUpdate;

  const _FlipCard({required this.item, required this.english, required this.onUpdate});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = item.status == 'Sold';
    final statusText = sold ? t('VERKAUFT', 'SOLD') : item.status == 'Listed' ? t('INSERIERT', 'LISTED') : t('GEKAUFT', 'BOUGHT');
    final statusColor = sold ? const Color(0xFF0A8F6A) : item.status == 'Listed' ? const Color(0xFF4A64C8) : const Color(0xFFC77A00);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                child: Icon(sold ? Icons.check_rounded : Icons.sell_outlined, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                    const SizedBox(height: 3),
                    TinyLabel(text: statusText, color: statusColor, background: statusColor.withValues(alpha: 0.08)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(sold ? euro(item.profit) : euro(item.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: sold && item.profit >= 0 ? const Color(0xFF0A8F6A) : const Color(0xFF242630))),
                  Text(sold ? t('Gewinn', 'profit') : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A8E9C))),
                ],
              ),
            ],
          ),
          if (!sold) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.status == 'Bought')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUpdate(item.copyWith(status: 'Listed')),
                      child: Text(t('Als inseriert markieren', 'Mark listed')),
                    ),
                  ),
                if (item.status == 'Listed')
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _markSold(context),
                      child: Text(t('Verkauft', 'Sold')),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markSold(BuildContext context) async {
    final controller = TextEditingController(text: item.sell > 0 ? item.sell.toStringAsFixed(0) : '');
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Verkaufspreis', 'Sale price')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '€'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Abbrechen', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);
            },
            child: Text(t('Speichern', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) onUpdate(item.copyWith(status: 'Sold', sell: value));
  }
}
