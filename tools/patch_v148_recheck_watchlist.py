from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

if "ValueKey('v148-recheck-deal')" in app:
    print('V0.14.8 recheck/watchlist patch already applied')
    raise SystemExit(0)

assert 'version: 0.14.7+30' in pub
pub = pub.replace('version: 0.14.7+30', 'version: 0.14.8+31', 1)

# Make the fallback pricing coherent. Store-provided prices still override these.
assert "year?.price ?? '59,99 € / Jahr'" in app
assert "month?.price ?? '7,99 € / Monat'" in app
app = app.replace(
    "_V13PlanChoice(title: t('Jährlich', 'Yearly'), price: year?.price ?? '59,99 € / Jahr', badge: t('BESTER WERT', 'BEST VALUE'), enabled: year != null, onTap: year == null ? null : () => widget.monetization.buy(year))",
    "_V13PlanChoice(title: t('Jährlich', 'Yearly'), price: year?.price ?? '39,99 € / Jahr · ≈ 3,33 € / Monat', badge: t('33 % SPAREN', 'SAVE 33%'), enabled: year != null, onTap: year == null ? null : () => widget.monetization.buy(year))",
    1,
)
app = app.replace(
    "_V13PlanChoice(title: t('Monatlich', 'Monthly'), price: month?.price ?? '7,99 € / Monat', enabled: month != null, onTap: month == null ? null : () => widget.monetization.buy(month))",
    "_V13PlanChoice(title: t('Monatlich', 'Monthly'), price: month?.price ?? '4,99 € / Monat', enabled: month != null, onTap: month == null ? null : () => widget.monetization.buy(month))",
    1,
)

# Watchlist helpers and archived state.
anchor = "String _v147SourceUrl(String raw) {\n  final match = RegExp(r'https?://[^\\s]+', caseSensitive: false).firstMatch(raw);\n  return match?.group(0)?.trim() ?? '';\n}\n\n"
assert anchor in app
app = app.replace(anchor, anchor + """List<V13Flip> v148PrioritizeSaved(Iterable<V13Flip> input) {
  final out = input.where((e) => e.isSaved).toList();
  out.sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
  return out;
}

""", 1)
app = app.replace(
    "  bool get isSaved => status == 'Saved';\n  bool get isOpen => status == 'Bought' || status == 'Listed';",
    "  bool get isSaved => status == 'Saved';\n  bool get isArchived => status == 'Archived';\n  bool get isOpen => status == 'Bought' || status == 'Listed';",
    1,
)

# App-level real deletion callback.
app = app.replace(
    "  final ValueChanged<V13Flip> onUpdateFlip;\n  final ValueChanged<bool> onLanguage;",
    "  final ValueChanged<V13Flip> onUpdateFlip;\n  final ValueChanged<String> onDeleteFlip;\n  final ValueChanged<bool> onLanguage;",
    1,
)
app = app.replace(
    "    required this.onUpdateFlip,\n    required this.onLanguage,",
    "    required this.onUpdateFlip,\n    required this.onDeleteFlip,\n    required this.onLanguage,",
    1,
)
old_update = """              onUpdateFlip: (item) {
                final i = flips.indexWhere((e) => e.id == item.id);
                if (i >= 0) {
                  setState(() => flips[i] = item);
                  _save();
                }
              },
              onLanguage: (value) {"""
new_update = """              onUpdateFlip: (item) {
                final i = flips.indexWhere((e) => e.id == item.id);
                if (i >= 0) {
                  setState(() => flips[i] = item);
                  _save();
                }
              },
              onDeleteFlip: (id) {
                setState(() => flips.removeWhere((e) => e.id == id));
                _save();
              },
              onLanguage: (value) {"""
assert old_update in app
app = app.replace(old_update, new_update, 1)

# Recheck an existing snapshot through the same check page instead of duplicating it.
app = app.replace(
    '  Future<void> _openCheck(String raw) async {',
    '  Future<void> _openCheck(String raw, {V13Flip? existingSnapshot}) async {',
    1,
)
app = app.replace(
    "            onHistory: widget.onHistory,\n            onAddFlip: widget.onAddFlip,",
    "            onHistory: widget.onHistory,\n            onAddFlip: widget.onAddFlip,\n            existingSnapshot: existingSnapshot,\n            onUpdateFlip: widget.onUpdateFlip,",
    1,
)
scan_anchor = """  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)));
    if (code != null && code.trim().isNotEmpty && mounted) await _openCheck(code);
  }
"""
assert scan_anchor in app
app = app.replace(scan_anchor, """  Future<void> _recheckFlip(V13Flip flip) async {
    final raw = flip.sourceUrl.isNotEmpty ? '${flip.name}\\n${flip.sourceUrl}' : flip.name;
    await _openCheck(raw, existingSnapshot: flip);
  }

""" + scan_anchor, 1)

old_flips_page_call = """      V13FlipsPage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        monetization: widget.monetization,
        onUpdate: widget.onUpdateFlip,
        onPro: () => _openPaywall(context),
      ),"""
new_flips_page_call = """      V13FlipsPage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        monetization: widget.monetization,
        onUpdate: widget.onUpdateFlip,
        onDelete: widget.onDeleteFlip,
        onRecheck: _recheckFlip,
        onPro: () => _openPaywall(context),
      ),"""
assert old_flips_page_call in app
app = app.replace(old_flips_page_call, new_flips_page_call, 1)

# Existing-snapshot support on the check page.
app = app.replace(
    "  final ValueChanged<String> onHistory;\n  final ValueChanged<V13Flip> onAddFlip;",
    "  final ValueChanged<String> onHistory;\n  final ValueChanged<V13Flip> onAddFlip;\n  final V13Flip? existingSnapshot;\n  final ValueChanged<V13Flip>? onUpdateFlip;",
    1,
)
app = app.replace(
    "    required this.onHistory,\n    required this.onAddFlip,\n  });",
    "    required this.onHistory,\n    required this.onAddFlip,\n    this.existingSnapshot,\n    this.onUpdateFlip,\n  });",
    1,
)
old_init = """    final detected = widget.input.detectedPrice;
    if (detected != null && detected > 0) {
      buy.text = detected == detected.roundToDouble()
          ? detected.toStringAsFixed(0)
          : detected.toStringAsFixed(2).replaceAll('.', ',');
    }
    final canResolveListing = detected == null && SourceRegistry.sharedListingUrl(widget.input.raw) != null;"""
new_init = """    final detected = widget.input.detectedPrice;
    final existing = widget.existingSnapshot;
    if (detected != null && detected > 0) {
      buy.text = detected == detected.roundToDouble()
          ? detected.toStringAsFixed(0)
          : detected.toStringAsFixed(2).replaceAll('.', ',');
    } else if (existing != null && existing.buy > 0) {
      buy.text = existing.buy == existing.buy.roundToDouble()
          ? existing.buy.toStringAsFixed(0)
          : existing.buy.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (existing != null && existing.expectedAtBuy > 0) {
      manualSell.text = existing.expectedAtBuy == existing.expectedAtBuy.roundToDouble()
          ? existing.expectedAtBuy.toStringAsFixed(0)
          : existing.expectedAtBuy.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (existing != null && existing.costs > 0) {
      costs.text = existing.costs == existing.costs.roundToDouble()
          ? existing.costs.toStringAsFixed(0)
          : existing.costs.toStringAsFixed(2).replaceAll('.', ',');
    }
    final canResolveListing = detected == null && SourceRegistry.sharedListingUrl(widget.input.raw) != null;"""
assert old_init in app
app = app.replace(old_init, new_init, 1)
app = app.replace(
    '      if (buyPrice <= 0) {',
    '      if (buyPrice <= 0 || widget.existingSnapshot != null) {',
    1,
)
old_search_head = """    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final myToken = ++token;"""
new_search_head = """    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final preserveSnapshotFallback = widget.existingSnapshot != null && token == 0;
    final myToken = ++token;"""
assert old_search_head in app
app = app.replace(old_search_head, new_search_head, 1)
app = app.replace(
    "      manualCommitted = null;\n      manualSell.clear();\n      manualMode = false;",
    "      manualCommitted = null;\n      if (!preserveSnapshotFallback) manualSell.clear();\n      manualMode = false;",
    1,
)

old_snapshot = """  V13Flip? _dealSnapshot(String status) {
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

"""
new_snapshot = """  V13Flip? _dealSnapshot(String status) {
    final expected = expectedSale;
    if (buyPrice <= 0 || expected == null) return null;
    final now = DateTime.now();
    final existing = widget.existingSnapshot;
    final rawUrl = _v147SourceUrl(widget.input.raw);
    final createdAt = status == 'Bought' && existing?.isSaved == true
        ? now
        : (existing?.createdAt ?? now);
    return V13Flip(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: query.text.trim(),
      category: category,
      buy: buyPrice,
      expectedAtBuy: expected,
      costs: extraCosts,
      sourceCount: resaleValues.length,
      confidence: confidence,
      status: status,
      createdAt: createdAt,
      checkedAt: now,
      sourceUrl: rawUrl.isNotEmpty ? rawUrl : (existing?.sourceUrl ?? ''),
      maxBuyAtCheck: maxBuy ?? 0,
      profitAtCheck: profit,
      roiAtCheck: roi,
      confidenceScore: marketConfidence.score,
    );
  }

  void _remember() {
    final item = _dealSnapshot('Saved');
    if (item == null) return;
    final updating = widget.existingSnapshot != null && widget.onUpdateFlip != null;
    if (updating) {
      widget.onUpdateFlip!(item);
    } else {
      widget.onAddFlip(item);
    }
    setState(() => savedWatch = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(updating ? 'Deal aktualisiert.' : 'Deal gemerkt.', updating ? 'Deal updated.' : 'Deal saved.'))));
  }

  void _bought() {
    final item = _dealSnapshot('Bought');
    if (item == null) return;
    if (widget.existingSnapshot != null && widget.onUpdateFlip != null) {
      widget.onUpdateFlip!(item);
    } else {
      widget.onAddFlip(item);
    }
    setState(() => savedBought = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Als gekauft gespeichert.', 'Saved as bought.'))));
  }

"""
assert old_snapshot in app
app = app.replace(old_snapshot, new_snapshot, 1)

# Flips page gets recheck/delete/archive management and stale-first saved ordering.
old_page_fields = """class V13FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<V13Flip> onUpdate;
  final VoidCallback onPro;

  const V13FlipsPage({super.key, required this.english, required this.plan, required this.flips, required this.monetization, required this.onUpdate, required this.onPro});"""
new_page_fields = """class V13FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback onPro;

  const V13FlipsPage({super.key, required this.english, required this.plan, required this.flips, required this.monetization, required this.onUpdate, required this.onDelete, required this.onRecheck, required this.onPro});"""
assert old_page_fields in app
app = app.replace(old_page_fields, new_page_fields, 1)
old_lists = """    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final saved = widget.flips.where((e) => e.isSaved).toList();
    final open = widget.flips.where((e) => e.isOpen).toList();
    final shown = filter == 'saved' ? saved : filter == 'sold' ? sold : filter == 'all' ? widget.flips : open;"""
new_lists = """    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final saved = v148PrioritizeSaved(widget.flips);
    final archived = widget.flips.where((e) => e.isArchived).toList()
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    final open = widget.flips.where((e) => e.isOpen).toList();
    final shown = filter == 'saved'
        ? saved
        : filter == 'archived'
            ? archived
            : filter == 'sold'
                ? sold
                : filter == 'all'
                    ? widget.flips
                    : open;"""
assert old_lists in app
app = app.replace(old_lists, new_lists, 1)
old_segment = "SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: [ButtonSegment(value: 'saved', icon: const Icon(Icons.bookmark_outline_rounded, size: 16), label: Text(t('Merkliste', 'Saved'))), ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first)))"
new_segment = "SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: [ButtonSegment(value: 'saved', icon: const Icon(Icons.bookmark_outline_rounded, size: 16), label: Text(t('Merkliste', 'Saved'))), ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'archived', icon: const Icon(Icons.archive_outlined, size: 16), label: Text(t('Archiv', 'Archive'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first)))"
assert old_segment in app
app = app.replace(old_segment, new_segment, 1)
app = app.replace(
    "_V13FlipCard(english: widget.english, flip: shown[i], onUpdate: widget.onUpdate)",
    "_V13FlipCard(english: widget.english, flip: shown[i], onUpdate: widget.onUpdate, onDelete: widget.onDelete, onRecheck: widget.onRecheck)",
    1,
)

# Replace the card so saved deals have a clean recheck action + overflow management.
card_start = app.index('class _V13FlipCard extends StatelessWidget {')
card_end = app.index('class V13SettingsPage extends StatefulWidget {', card_start)
new_card = r'''class _V13FlipCard extends StatelessWidget {
  final bool english;
  final V13Flip flip;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  const _V13FlipCard({required this.english, required this.flip, required this.onUpdate, required this.onDelete, required this.onRecheck});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flip.status == 'Sold';
    final saved = flip.isSaved;
    final archived = flip.isArchived;
    final age = DateTime.now().difference(flip.checkedAt);
    final stale = saved && age.inHours >= 24;
    final stateLabel = sold
        ? t('verkauft', 'sold')
        : archived
            ? t('archiviert', 'archived')
            : saved
                ? t('gemerkt', 'saved')
                : flip.status == 'Listed'
                    ? t('inseriert', 'listed')
                    : t('gekauft', 'bought');
    final iconColor = sold
        ? const Color(0xFF087F5B)
        : archived
            ? const Color(0xFF7A7E8B)
            : saved
                ? const Color(0xFFC47B00)
                : _v13Primary;
    return Container(
      key: ValueKey('v147-flip-${flip.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: stale ? const Color(0x33C47B00) : const Color(0xFFE9EAF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(sold ? Icons.check_rounded : archived ? Icons.archive_outlined : saved ? Icons.bookmark_rounded : Icons.inventory_2_outlined, color: iconColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(flip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${flip.category} · $stateLabel', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B)))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(sold ? v13Euro(flip.realizedProfit) : v13Euro(flip.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sold && flip.realizedProfit >= 0 ? const Color(0xFF087F5B) : _v13Ink)), Text(sold ? '${flip.daysToSell ?? 0} ${t('Tage', 'days')}' : saved || archived ? t('Angebot', 'asking') : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B8E9A)))]),
          if (saved || archived) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              key: ValueKey('v148-menu-${flip.id}'),
              tooltip: t('Deal verwalten', 'Manage deal'),
              onSelected: (value) => _handleMenu(context, value),
              itemBuilder: (_) => [
                if (flip.sourceUrl.isNotEmpty) PopupMenuItem(value: 'listing', child: Text(t('Inserat öffnen', 'Open listing'))),
                if (saved) PopupMenuItem(value: 'archive', child: Text(t('Archivieren', 'Archive'))),
                if (archived) PopupMenuItem(value: 'restore', child: Text(t('Zur Merkliste', 'Restore to saved'))),
                PopupMenuItem(value: 'delete', child: Text(t('Löschen', 'Delete'))),
              ],
            ),
          ],
        ]),
        if (saved || archived || (!sold && flip.maxBuyAtCheck > 0)) ...[
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
        if (!sold && !archived) ...[
          const SizedBox(height: 10),
          if (saved)
            Row(children: [
              Expanded(child: OutlinedButton.icon(key: const ValueKey('v148-recheck-deal'), onPressed: () => onRecheck(flip), icon: const Icon(Icons.refresh_rounded, size: 17), label: Text(t('NEU PRÜFEN', 'RECHECK')))),
              const SizedBox(width: 7),
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

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'listing':
        await _openListing();
      case 'archive':
        onUpdate(flip.copyWith(status: 'Archived'));
      case 'restore':
        onUpdate(flip.copyWith(status: 'Saved'));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Deal löschen?', 'Delete deal?')),
            content: Text(t('Der gespeicherte Snapshot wird dauerhaft von diesem Gerät entfernt.', 'The saved snapshot will be permanently removed from this device.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('Löschen', 'Delete'))),
            ],
          ),
        );
        if (ok == true) onDelete(flip.id);
    }
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
print('V0.14.8 recheck/watchlist patch applied')
