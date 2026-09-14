from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()

anchor = """        const SizedBox(height: 12),\n        if (shown.isEmpty)\n"""
replacement = """        const SizedBox(height: 12),\n        if (filter == 'saved' && saved.isNotEmpty) ...[\n          _V149WatchlistAttention(\n            english: widget.english,\n            saved: saved,\n            onRecheck: widget.onRecheck,\n          ),\n          const SizedBox(height: 10),\n        ],\n        if (shown.isEmpty)\n"""
if "ValueKey('v149-watchlist-attention')" not in app:
    if anchor not in app:
        raise SystemExit('watchlist insertion anchor not found')
    app = app.replace(anchor, replacement, 1)

widget_anchor = "class _V13DarkStat extends StatelessWidget {"
widget_code = """class _V149WatchlistAttention extends StatelessWidget {\n  final bool english;\n  final List<V13Flip> saved;\n  final ValueChanged<V13Flip> onRecheck;\n  const _V149WatchlistAttention({required this.english, required this.saved, required this.onRecheck});\n\n  String t(String de, String en) => english ? en : de;\n\n  @override\n  Widget build(BuildContext context) {\n    final now = DateTime.now();\n    final stale = saved.where((e) => now.difference(e.checkedAt).inHours >= 24).toList();\n    final oldest = saved.first;\n    final title = stale.isEmpty\n        ? t('Merkliste aktuell', 'Watchlist up to date')\n        : t('${stale.length} Deal${stale.length == 1 ? '' : 's'} neu prüfen', '${stale.length} deal${stale.length == 1 ? '' : 's'} to recheck');\n    final subtitle = stale.isEmpty\n        ? t('Alle gespeicherten Deals wurden in den letzten 24 Std. geprüft.', 'All saved deals were checked within the last 24h.')\n        : t('Ältester Check ${v147AgeLabel(oldest.checkedAt, false)}.', 'Oldest check ${v147AgeLabel(oldest.checkedAt, true)}.');\n    return Container(\n      key: const ValueKey('v149-watchlist-attention'),\n      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),\n      decoration: BoxDecoration(\n        color: stale.isEmpty ? const Color(0xFFF2F7F4) : const Color(0xFFFFF7E8),\n        borderRadius: BorderRadius.circular(17),\n        border: Border.all(color: stale.isEmpty ? const Color(0x22087F5B) : const Color(0x33C47B00)),\n      ),\n      child: Row(children: [\n        Icon(stale.isEmpty ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined, color: stale.isEmpty ? const Color(0xFF087F5B) : const Color(0xFFC47B00), size: 21),\n        const SizedBox(width: 9),\n        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),\n          const SizedBox(height: 2),\n          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF707481))),\n        ])),\n        if (stale.isNotEmpty)\n          TextButton(\n            key: const ValueKey('v149-recheck-oldest'),\n            onPressed: () => onRecheck(oldest),\n            child: Text(t('PRÜFEN', 'CHECK')),\n          ),\n      ]),\n    );\n  }\n}\n\n"""
if "class _V149WatchlistAttention" not in app:
    if widget_anchor not in app:
        raise SystemExit('watchlist widget anchor not found')
    app = app.replace(widget_anchor, widget_code + widget_anchor, 1)

path.write_text(app)
print('V0.14.9 watchlist attention summary applied')
