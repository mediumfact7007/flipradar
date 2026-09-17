from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()

if "v152-watchlist-home-attention" in text:
    print('watchlist home attention already applied')
    raise SystemExit(0)

replacements = [
("""  int tab = 0;
  bool opening = false;""", """  int tab = 0;
  String flipsInitialFilter = 'open';
  bool opening = false;"""),
("""    final pages = [
      V13Home(
        english: widget.english,
        plan: widget.plan,
        history: widget.history,
        openFlips: widget.flips.where((e) => e.isOpen).length,
        monetization: widget.monetization,
        onSearch: _openCheck,
        onScan: _scan,
        onSettings: _settings,
        onOpenFlips: () => setState(() => tab = 1),
      ),""", """    final savedFlips = v148PrioritizeSaved(widget.flips);
    final staleSaved = savedFlips.where((e) => DateTime.now().difference(e.checkedAt).inHours >= 24).length;
    final pages = [
      V13Home(
        english: widget.english,
        plan: widget.plan,
        history: widget.history,
        openFlips: widget.flips.where((e) => e.isOpen).length,
        savedFlips: savedFlips.length,
        staleSaved: staleSaved,
        monetization: widget.monetization,
        onSearch: _openCheck,
        onScan: _scan,
        onSettings: _settings,
        onOpenFlips: () => setState(() { flipsInitialFilter = 'open'; tab = 1; }),
        onOpenSaved: () => setState(() { flipsInitialFilter = 'saved'; tab = 1; }),
      ),"""),
("""        onRecheck: _recheckFlip,
        onPro: () => _openPaywall(context),
      ),""", """        onRecheck: _recheckFlip,
        onPro: () => _openPaywall(context),
        initialFilter: flipsInitialFilter,
      ),"""),
("""  final List<String> history;
  final int openFlips;
  final V13Monetization monetization;""", """  final List<String> history;
  final int openFlips;
  final int savedFlips;
  final int staleSaved;
  final V13Monetization monetization;"""),
("""  final VoidCallback onSettings;
  final VoidCallback onOpenFlips;""", """  final VoidCallback onSettings;
  final VoidCallback onOpenFlips;
  final VoidCallback onOpenSaved;"""),
("""    required this.history,
    required this.openFlips,
    required this.monetization,""", """    required this.history,
    required this.openFlips,
    required this.savedFlips,
    required this.staleSaved,
    required this.monetization,"""),
("""    required this.onSettings,
    required this.onOpenFlips,
  });""", """    required this.onSettings,
    required this.onOpenFlips,
    required this.onOpenSaved,
  });"""),
("""        if (widget.openFlips > 0) ...[
          const SizedBox(height: 13),
          OutlinedButton.icon(""", """        if (widget.savedFlips > 0) ...[
          const SizedBox(height: 13),
          Material(
            key: const ValueKey('v152-watchlist-home-attention'),
            color: widget.staleSaved > 0 ? const Color(0xFFFFF7E8) : const Color(0xFFF4F5FA),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              onTap: widget.onOpenSaved,
              leading: Icon(widget.staleSaved > 0 ? Icons.notifications_active_outlined : Icons.bookmark_rounded, color: widget.staleSaved > 0 ? const Color(0xFFC47B00) : _v13Primary),
              title: Text(widget.staleSaved > 0 ? t('${widget.staleSaved} gespeicherte Deals neu prüfen', '${widget.staleSaved} saved deals need a recheck') : t('${widget.savedFlips} Deals gemerkt', '${widget.savedFlips} deals saved'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              subtitle: Text(widget.staleSaved > 0 ? t('Marktpreise sind älter als 24 Std.', 'Market prices are older than 24h.') : t('Merkliste öffnen und Preise erneut prüfen.', 'Open saved deals and recheck prices.'), style: const TextStyle(fontSize: 10.8)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
        if (widget.openFlips > 0) ...[
          const SizedBox(height: 13),
          OutlinedButton.icon("""),
("""  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback onPro;

  const V13FlipsPage({super.key, required this.english, required this.plan, required this.flips, required this.monetization, required this.onUpdate, required this.onDelete, required this.onRecheck, required this.onPro});""", """  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback onPro;
  final String initialFilter;

  const V13FlipsPage({super.key, required this.english, required this.plan, required this.flips, required this.monetization, required this.onUpdate, required this.onDelete, required this.onRecheck, required this.onPro, this.initialFilter = 'open'});"""),
("""class _V13FlipsPageState extends State<V13FlipsPage> {
  String filter = 'open';
  String t(String de, String en) => widget.english ? en : de;""", """class _V13FlipsPageState extends State<V13FlipsPage> {
  late String filter;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }"""),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'guard failed: expected exactly one match, got {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)

path.write_text(text)
print('applied watchlist home attention patch')
