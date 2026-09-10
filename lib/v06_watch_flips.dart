part of 'v06.dart';

class WatchPage extends StatelessWidget {
  final bool english;
  final UserPlan plan;
  final List<WatchItem> items;
  final ValueChanged<String> onCheck;
  final ValueChanged<String> onRemove;

  const WatchPage({
    super.key,
    required this.english,
    required this.plan,
    required this.items,
    required this.onCheck,
    required this.onRemove,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Merkliste', 'Watchlist'), t('Interessante Produkte mit deinem persönlichen Kauf-Limit.', 'Interesting products with your personal buy limit.')),
        const SizedBox(height: 14),
        if (items.isEmpty)
          infoBox(context, Icons.bookmark_border, t('Noch nichts gemerkt. Prüfe einen Deal und tippe danach auf „Merken“.', 'Nothing saved yet. Check a deal and then tap Watch.'))
        else
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            return Column(
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.notifications_none)),
                    title: Text(item.query, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(t('Kaufen bis ${item.maxBuy.toStringAsFixed(0)} €', 'Buy up to ${item.maxBuy.toStringAsFixed(0)} €')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'check') onCheck(item.query);
                        if (v == 'remove') onRemove(item.query);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'check', child: Text(t('Neu prüfen', 'Check again'))),
                        PopupMenuItem(value: 'remove', child: Text(t('Entfernen', 'Remove'))),
                      ],
                    ),
                    onTap: () => onCheck(item.query),
                  ),
                ),
                if (plan == UserPlan.free && entry.key == 2) ...[
                  const SizedBox(height: 8),
                  SponsoredStrip(english: english),
                ],
                const SizedBox(height: 8),
              ],
            );
          }),
        const SizedBox(height: 8),
        infoBox(
          context,
          Icons.schedule,
          plan == UserPlan.free
              ? t('Automatische Preisalarme sind für PRO vorgesehen. In FREE kannst du jederzeit mit einem Tipp neu prüfen.', 'Automatic price alerts are planned for PRO. In FREE you can re-check anytime with one tap.')
              : t('Dein Tarif ist für automatische Preisalarme vorbereitet, sobald der Server online ist.', 'Your plan is ready for automatic price alerts once the server is online.'),
        ),
      ],
    );
  }
}

class FlipsPage extends StatelessWidget {
  final bool english;
  final List<FlipItem> flips;
  final ValueChanged<FlipItem> onUpdate;

  const FlipsPage({
    super.key,
    required this.english,
    required this.flips,
    required this.onUpdate,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flips.where((e) => e.status == 'Sold');
    final realized = sold.fold<double>(0, (a, b) => a + b.profit);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Meine Flips', 'My flips'), t('Vom Einkauf bis zum Verkauf – ohne Excel.', 'From purchase to sale – without spreadsheets.')),
        const SizedBox(height: 12),
        smallMetric(t('Realisierter Gewinn', 'Realized profit'), '${realized.toStringAsFixed(0)} €', Icons.savings_outlined),
        const SizedBox(height: 14),
        if (flips.isEmpty)
          infoBox(context, Icons.inventory_2_outlined, t('Noch keine Flips gespeichert.', 'No flips saved yet.'))
        else
          ...flips.map((f) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${f.buy.toStringAsFixed(0)} € → ${f.sell.toStringAsFixed(0)} € · ${t('Gewinn', 'profit')} ${f.profit.toStringAsFixed(0)} € · ROI ${f.roi.toStringAsFixed(0)} %'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => onUpdate(f.copyWith(status: v)),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'Bought', child: Text(t('Gekauft', 'Bought'))),
                      PopupMenuItem(value: 'Listed', child: Text(t('Inseriert', 'Listed'))),
                      PopupMenuItem(value: 'Sold', child: Text(t('Verkauft', 'Sold'))),
                    ],
                    child: Chip(label: Text(statusLabel(f.status, english))),
                  ),
                ),
              )),
      ],
    );
  }
}
