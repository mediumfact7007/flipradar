from pathlib import Path
import re

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

if "ValueKey('v147-remember-deal')" in app:
    print('V0.14.7 deal-memory patch already applied')
    raise SystemExit(0)

assert 'version: 0.14.6+29' in pub
pub = pub.replace('version: 0.14.6+29', 'version: 0.14.7+30', 1)

start = app.index('class V13Flip {')
end = app.index('class V13PersonalStats {', start)
flip_block = r'''String v147AgeLabel(DateTime checkedAt, bool english, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(checkedAt);
  if (age.isNegative || age.inMinutes < 2) return english ? 'just now' : 'gerade eben';
  if (age.inMinutes < 60) return english ? '${age.inMinutes} min ago' : 'vor ${age.inMinutes} Min';
  if (age.inHours < 24) return english ? '${age.inHours} h ago' : 'vor ${age.inHours} Std';
  if (age.inDays < 30) return english ? '${age.inDays} d ago' : 'vor ${age.inDays} T';
  final months = (age.inDays / 30).floor();
  return english ? '${months} mo ago' : 'vor ${months} Mon';
}

String _v147SourceUrl(String raw) {
  final match = RegExp(r'https?://[^\\s]+', caseSensitive: false).firstMatch(raw);
  return match?.group(0)?.trim() ?? '';
}

class V13Flip {
  final String id;
  final String name;
  final String category;
  final double buy;
  final double expectedAtBuy;
  final double costs;
  final int sourceCount;
  final String confidence;
  final String status;
  final DateTime createdAt;
  final DateTime checkedAt;
  final DateTime? listedAt;
  final DateTime? soldAt;
  final double actualSell;
  final String soldPlatform;
  final String sourceUrl;
  final double maxBuyAtCheck;
  final double profitAtCheck;
  final double roiAtCheck;
  final int confidenceScore;

  const V13Flip({
    required this.id,
    required this.name,
    required this.category,
    required this.buy,
    required this.expectedAtBuy,
    required this.costs,
    required this.sourceCount,
    required this.confidence,
    required this.status,
    required this.createdAt,
    DateTime? checkedAt,
    this.listedAt,
    this.soldAt,
    this.actualSell = 0,
    this.soldPlatform = '',
    this.sourceUrl = '',
    this.maxBuyAtCheck = 0,
    this.profitAtCheck = 0,
    this.roiAtCheck = 0,
    this.confidenceScore = 0,
  }) : checkedAt = checkedAt ?? createdAt;

  bool get isSaved => status == 'Saved';
  bool get isOpen => status == 'Bought' || status == 'Listed';
  double get realizedProfit => actualSell > 0 ? actualSell - buy - costs : 0;
  double get realizedRoi => buy <= 0 ? 0 : realizedProfit / buy * 100;
  int? get daysToSell => soldAt == null ? null : math.max(0, soldAt!.difference(createdAt).inDays);

  V13Flip copyWith({
    String? status,
    DateTime? createdAt,
    DateTime? checkedAt,
    DateTime? listedAt,
    DateTime? soldAt,
    double? actualSell,
    String? soldPlatform,
  }) =>
      V13Flip(
        id: id,
        name: name,
        category: category,
        buy: buy,
        expectedAtBuy: expectedAtBuy,
        costs: costs,
        sourceCount: sourceCount,
        confidence: confidence,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        checkedAt: checkedAt ?? this.checkedAt,
        listedAt: listedAt ?? this.listedAt,
        soldAt: soldAt ?? this.soldAt,
        actualSell: actualSell ?? this.actualSell,
        soldPlatform: soldPlatform ?? this.soldPlatform,
        sourceUrl: sourceUrl,
        maxBuyAtCheck: maxBuyAtCheck,
        profitAtCheck: profitAtCheck,
        roiAtCheck: roiAtCheck,
        confidenceScore: confidenceScore,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'buy': buy,
        'expectedAtBuy': expectedAtBuy,
        'costs': costs,
        'sourceCount': sourceCount,
        'confidence': confidence,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'checkedAt': checkedAt.toIso8601String(),
        'listedAt': listedAt?.toIso8601String(),
        'soldAt': soldAt?.toIso8601String(),
        'actualSell': actualSell,
        'soldPlatform': soldPlatform,
        'sourceUrl': sourceUrl,
        'maxBuyAtCheck': maxBuyAtCheck,
        'profitAtCheck': profitAtCheck,
        'roiAtCheck': roiAtCheck,
        'confidenceScore': confidenceScore,
      };

  factory V13Flip.fromJson(Map<String, dynamic> j) {
    final status = j['status']?.toString() ?? 'Bought';
    final legacySell = (j['sell'] as num?)?.toDouble() ?? 0;
    final actual = (j['actualSell'] as num?)?.toDouble() ?? (status == 'Sold' ? legacySell : 0);
    final created = DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now();
    return V13Flip(
      id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: j['name']?.toString() ?? 'Artikel',
      category: j['category']?.toString() ?? v13Category(j['name']?.toString() ?? ''),
      buy: (j['buy'] as num?)?.toDouble() ?? 0,
      expectedAtBuy: (j['expectedAtBuy'] as num?)?.toDouble() ?? legacySell,
      costs: (j['costs'] as num?)?.toDouble() ?? 0,
      sourceCount: (j['sourceCount'] as num?)?.toInt() ?? 0,
      confidence: j['confidence']?.toString() ?? 'Unbekannt',
      status: status,
      createdAt: created,
      checkedAt: DateTime.tryParse(j['checkedAt']?.toString() ?? '') ?? created,
      listedAt: DateTime.tryParse(j['listedAt']?.toString() ?? ''),
      soldAt: DateTime.tryParse(j['soldAt']?.toString() ?? '') ?? (status == 'Sold' ? created : null),
      actualSell: actual,
      soldPlatform: j['soldPlatform']?.toString() ?? '',
      sourceUrl: j['sourceUrl']?.toString() ?? '',
      maxBuyAtCheck: (j['maxBuyAtCheck'] as num?)?.toDouble() ?? 0,
      profitAtCheck: (j['profitAtCheck'] as num?)?.toDouble() ?? 0,
      roiAtCheck: (j['roiAtCheck'] as num?)?.toDouble() ?? 0,
      confidenceScore: (j['confidenceScore'] as num?)?.toInt() ?? 0,
    );
  }
}

'''
app = app[:start] + flip_block + app[end:]

app = app.replace(
    '  bool savedBought = false;\n  bool listingResolving = false;',
    '  bool savedBought = false;\n  bool savedWatch = false;\n  bool listingResolving = false;',
    1,
)
app = app.replace(
    '      savedBought = false;\n    });',
    '      savedBought = false;\n      savedWatch = false;\n    });',
    1,
)
app = app.replace(
    "        openFlips: widget.flips.where((e) => e.status != 'Sold').length,",
    "        openFlips: widget.flips.where((e) => e.isOpen).length,",
    1,
)

old_call = '''            onBought: d == V13Decision.waiting || savedBought ? null : _bought,
            onNegotiate: d == V13Decision.negotiate ? _copyOffer : null,'''
new_call = '''            onRemember: d == V13Decision.waiting || savedWatch || savedBought ? null : _remember,
            onBought: d == V13Decision.waiting || savedBought ? null : _bought,
            onNegotiate: d == V13Decision.negotiate ? _copyOffer : null,'''
assert old_call in app
app = app.replace(old_call, new_call, 1)

bought_start = app.index('  void _bought() {')
bought_end = app.index('  void _copyOffer() {', bought_start)
new_save = r'''  V13Flip? _dealSnapshot(String status) {
    final expected = expectedSale;
    if (buyPrice <= 0 || expected == null) return null;
    final now = DateTime.now();
    return V13Flip(
      id: now.microsecondsSinceEpoch.toString(),
      name: query.text.trim(),
      category: category,
      buy: buyPrice,
      expectedAtBuy: expected,
      costs: extraCosts,
      sourceCount: resaleValues.length,
      confidence: confidence,
      status: status,
      createdAt: now,
      checkedAt: now,
      sourceUrl: _v147SourceUrl(widget.input.raw),
      maxBuyAtCheck: maxBuy ?? 0,
      profitAtCheck: profit,
      roiAtCheck: roi,
      confidenceScore: marketConfidence.score,
    );
  }

  void _remember() {
    final item = _dealSnapshot('Saved');
    if (item == null) return;
    widget.onAddFlip(item);
    setState(() => savedWatch = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Deal gemerkt.', 'Deal saved.'))));
  }

  void _bought() {
    final item = _dealSnapshot('Bought');
    if (item == null) return;
    widget.onAddFlip(item);
    setState(() => savedBought = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Als gekauft gespeichert.', 'Saved as bought.'))));
  }

'''
app = app[:bought_start] + new_save + app[bought_end:]

app = app.replace(
    '  final VoidCallback? onBought;\n  final VoidCallback? onNegotiate;',
    '  final VoidCallback? onRemember;\n  final VoidCallback? onBought;\n  final VoidCallback? onNegotiate;',
    1,
)
app = app.replace(
    '  const _V13DecisionCard({required this.english, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.buyPrice, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onBought, this.onNegotiate});',
    '  const _V13DecisionCard({required this.english, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.buyPrice, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onRemember, this.onBought, this.onNegotiate});',
    1,
)
old_actions = '''          Row(children: [
            if (onBought != null) Expanded(child: FilledButton.icon(onPressed: onBought, icon: const Icon(Icons.inventory_2_rounded), label: Text(t('GEKAUFT', 'BOUGHT')))),
            if (onBought != null && onNegotiate != null) const SizedBox(width: 7),
            if (onNegotiate != null) Expanded(child: OutlinedButton.icon(onPressed: onNegotiate, icon: const Icon(Icons.copy_rounded, size: 18), label: Text(t('PREISVORSCHLAG', 'OFFER')))),
          ]),'''
new_actions = '''          Row(children: [
            if (onRemember != null) Expanded(child: OutlinedButton.icon(key: const ValueKey('v147-remember-deal'), onPressed: onRemember, icon: const Icon(Icons.bookmark_add_outlined, size: 18), label: Text(t('MERKEN', 'SAVE')))),
            if (onRemember != null && onBought != null) const SizedBox(width: 7),
            if (onBought != null) Expanded(child: FilledButton.icon(onPressed: onBought, icon: const Icon(Icons.inventory_2_rounded), label: Text(t('GEKAUFT', 'BOUGHT')))),
          ]),
          if (onNegotiate != null) ...[
            const SizedBox(height: 7),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onNegotiate, icon: const Icon(Icons.copy_rounded, size: 18), label: Text(t('PREISVORSCHLAG KOPIEREN', 'COPY OFFER')))),
          ],'''
assert old_actions in app
app = app.replace(old_actions, new_actions, 1)

old_lists = '''    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final open = widget.flips.where((e) => e.status != 'Sold').toList();
    final shown = filter == 'sold' ? sold : filter == 'all' ? widget.flips : open;
    final profit = sold.fold<double>(0, (a, b) => a + b.realizedProfit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);'''
new_lists = '''    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final saved = widget.flips.where((e) => e.isSaved).toList();
    final open = widget.flips.where((e) => e.isOpen).toList();
    final shown = filter == 'saved' ? saved : filter == 'sold' ? sold : filter == 'all' ? widget.flips : open;
    final profit = sold.fold<double>(0, (a, b) => a + b.realizedProfit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);'''
assert old_lists in app
app = app.replace(old_lists, new_lists, 1)

old_segment = "        SegmentedButton<String>(segments: [ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first)),"
new_segment = "        SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: [ButtonSegment(value: 'saved', icon: const Icon(Icons.bookmark_outline_rounded, size: 16), label: Text(t('Merkliste', 'Saved'))), ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first))),"
assert old_segment in app
app = app.replace(old_segment, new_segment, 1)

card_start = app.index('class _V13FlipCard extends StatelessWidget {')
card_end = app.index('class V13SettingsPage extends StatefulWidget {', card_start)
new_card = r'''class _V13FlipCard extends StatelessWidget {
  final bool english;
  final V13Flip flip;
  final ValueChanged<V13Flip> onUpdate;
  const _V13FlipCard({required this.english, required this.flip, required this.onUpdate});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flip.status == 'Sold';
    final saved = flip.isSaved;
    final age = DateTime.now().difference(flip.checkedAt);
    final stale = saved && age.inHours >= 24;
    final stateLabel = sold
        ? t('verkauft', 'sold')
        : saved
            ? t('gemerkt', 'saved')
            : flip.status == 'Listed'
                ? t('inseriert', 'listed')
                : t('gekauft', 'bought');
    final iconColor = sold ? const Color(0xFF087F5B) : saved ? const Color(0xFFC47B00) : _v13Primary;
    return Container(
      key: ValueKey('v147-flip-${flip.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: stale ? const Color(0x33C47B00) : const Color(0xFFE9EAF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(sold ? Icons.check_rounded : saved ? Icons.bookmark_rounded : Icons.inventory_2_outlined, color: iconColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(flip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${flip.category} · $stateLabel', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B)))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(sold ? v13Euro(flip.realizedProfit) : v13Euro(flip.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sold && flip.realizedProfit >= 0 ? const Color(0xFF087F5B) : _v13Ink)), Text(sold ? '${flip.daysToSell ?? 0} ${t('Tage', 'days')}' : saved ? t('Angebot', 'asking') : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B8E9A)))])
        ]),
        if (saved || (!sold && flip.maxBuyAtCheck > 0)) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (flip.maxBuyAtCheck > 0) _V13Pill(text: 'MAX ${v13Euro(flip.maxBuyAtCheck)}', foreground: _v13Primary, background: const Color(0xFFEDEDFC)),
            if (flip.profitAtCheck != 0) _V13Pill(text: '${flip.profitAtCheck >= 0 ? '+' : ''}${v13Euro(flip.profitAtCheck)}', foreground: flip.profitAtCheck >= 0 ? const Color(0xFF087F5B) : const Color(0xFFC33A46), background: const Color(0xFFF4F5F8)),
            if (flip.roiAtCheck != 0) _V13Pill(text: 'ROI ${flip.roiAtCheck.toStringAsFixed(0)} %', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
            if (flip.confidenceScore > 0) _V13Pill(text: '${flip.confidenceScore}/100', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
          ]),
          const SizedBox(height: 6),
          Row(key: const ValueKey('v147-snapshot-age'), children: [
            Icon(stale ? Icons.schedule_rounded : Icons.history_rounded, size: 14, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B)),
            const SizedBox(width: 5),
            Expanded(child: Text(
              stale
                  ? t('Check ${v147AgeLabel(flip.checkedAt, false)} · Preise können veraltet sein.', 'Checked ${v147AgeLabel(flip.checkedAt, true)} · prices may be stale.')
                  : t('Check ${v147AgeLabel(flip.checkedAt, false)}.', 'Checked ${v147AgeLabel(flip.checkedAt, true)}.'),
              style: TextStyle(fontSize: 10.2, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B), fontWeight: stale ? FontWeight.w800 : FontWeight.w500),
            )),
          ]),
        ],
        if (!sold) ...[
          const SizedBox(height: 10),
          if (saved)
            Row(children: [
              if (flip.sourceUrl.isNotEmpty) ...[
                Expanded(child: OutlinedButton.icon(onPressed: () => _openListing(), icon: const Icon(Icons.open_in_new_rounded, size: 17), label: Text(t('INSERAT', 'LISTING')))),
                const SizedBox(width: 7),
              ],
              Expanded(child: FilledButton.icon(key: const ValueKey('v147-mark-bought'), onPressed: () => onUpdate(flip.copyWith(status: 'Bought', createdAt: DateTime.now())), icon: const Icon(Icons.inventory_2_rounded, size: 17), label: Text(t('GEKAUFT', 'BOUGHT')))),
            ])
          else
            Row(children: [
              if (flip.status == 'Bought') Expanded(child: OutlinedButton(onPressed: () => onUpdate(flip.copyWith(status: 'Listed', listedAt: DateTime.now())), child: Text(t('Inseriert', 'Listed')))),
              if (flip.status == 'Bought') const SizedBox(width: 7),
              Expanded(child: FilledButton(onPressed: () => _soldDialog(context), child: Text(t('Verkauft', 'Sold')))),
            ]),
        ],
      ]),
    );
  }

  Future<void> _openListing() async {
    final uri = Uri.tryParse(flip.sourceUrl);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _soldDialog(BuildContext context) async {
    final price = TextEditingController();
    var platform = 'eBay';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(t('Verkauf abschließen', 'Finish sale')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: price, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Verkaufspreis', 'Sale price'), suffixText: '€')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: platform, decoration: InputDecoration(labelText: t('Verkauft über', 'Sold on')), items: ['eBay', 'Kleinanzeigen', 'Vinted', 'Amazon', 'rebuy', t('Sonstiges', 'Other')].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialog(() => platform = v ?? platform)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('Abbrechen', 'Cancel'))), FilledButton(onPressed: () { final value = v13Money(price.text); if (value > 0) Navigator.pop(dialogContext, {'price': value, 'platform': platform}); }, child: Text(t('Speichern', 'Save')))],
      )),
    );
    price.dispose();
    if (result != null) {
      onUpdate(flip.copyWith(status: 'Sold', soldAt: DateTime.now(), actualSell: result['price'] as double, soldPlatform: result['platform'] as String));
    }
  }
}

'''
app = app[:card_start] + new_card + app[card_end:]

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.7 deal-memory patch applied')
