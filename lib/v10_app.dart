import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'source_registry.dart';
import 'v07.dart';
import 'v09_app.dart' show extractSharedQuery, parseMoneyInput;

class FlipRadarV10App extends StatefulWidget {
  const FlipRadarV10App({super.key});

  @override
  State<FlipRadarV10App> createState() => _FlipRadarV10AppState();
}

class _FlipRadarV10AppState extends State<FlipRadarV10App> {
  bool loading = true;
  bool english = false;
  String backend = '';
  double targetRoi = 35;
  UserPlan plan = UserPlan.free;
  List<FlipItem> flips = [];
  List<WatchItem> watchlist = [];
  List<String> history = [];
  List<PriceSource> sources = [];
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final storedFlips = <FlipItem>[];
      final storedWatch = <WatchItem>[];
      final flipRaw = p.getStringList('flips_v10') ?? p.getStringList('flips_v09') ?? <String>[];
      final watchRaw = p.getStringList('watch_v10') ?? p.getStringList('watch_v09') ?? <String>[];

      for (final raw in flipRaw) {
        try {
          final item = FlipItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (item.name.trim().isNotEmpty && item.buy >= 0 && item.sell >= 0 && item.costs >= 0) {
            storedFlips.add(item);
          }
        } catch (_) {}
      }
      for (final raw in watchRaw) {
        try {
          final item = WatchItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (item.query.trim().isNotEmpty && item.maxBuy >= 0) storedWatch.add(item);
        } catch (_) {}
      }

      final loadedBackend = p.getString('backend_v10') ?? p.getString('backend_v09') ?? '';
      final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
      if (!mounted) return;
      final rawPlan = p.getInt('plan_preview_v10') ?? p.getInt('plan_preview_v09') ?? 0;
      final rawRoi = p.getDouble('roi_v10') ?? p.getDouble('roi_v09') ?? 35;
      setState(() {
        english = p.getBool('english_v10') ?? p.getBool('english_v09') ?? false;
        backend = loadedBackend.trim();
        targetRoi = rawRoi.isFinite ? rawRoi.clamp(10, 100).toDouble() : 35.0;
        plan = UserPlan.values[rawPlan.clamp(0, UserPlan.values.length - 1)];
        if (plan == UserPlan.proPlus) plan = UserPlan.pro;
        flips = storedFlips;
        watchlist = storedWatch;
        history = (p.getStringList('history_v10') ?? p.getStringList('history_v09') ?? <String>[])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .take(10)
            .toList();
        sources = loadedSources;
        loading = false;
      });
    } catch (_) {
      final fallback = await SourceRegistry.load();
      if (!mounted) return;
      setState(() {
        sources = fallback;
        loading = false;
      });
    }
  }

  void _save() {
    _saveQueue = _saveQueue.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setBool('english_v10', english);
      await p.setString('backend_v10', backend);
      await p.setDouble('roi_v10', targetRoi);
      await p.setInt('plan_preview_v10', plan.index);
      await p.setStringList('flips_v10', flips.map((e) => jsonEncode(e.toJson())).toList());
      await p.setStringList('watch_v10', watchlist.map((e) => jsonEncode(e.toJson())).toList());
      await p.setStringList('history_v10', history.take(10).toList());
    }).catchError((_) {});
  }

  void _addHistory(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      history.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      history.insert(0, q);
      if (history.length > 10) history = history.take(10).toList();
    });
    _save();
  }

  void _addWatch(WatchItem item) {
    setState(() {
      watchlist.removeWhere((e) => e.query.toLowerCase() == item.query.toLowerCase());
      watchlist.insert(0, item);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4E50D8),
      brightness: Brightness.light,
      surface: const Color(0xFFF6F7FB),
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6E7EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF4E50D8), width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _FastShell(
              english: english,
              backend: backend,
              targetRoi: targetRoi,
              plan: plan,
              flips: flips,
              watchlist: watchlist,
              history: history,
              sources: sources,
              onLanguage: (v) {
                setState(() => english = v);
                _save();
              },
              onBackend: (v) async {
                setState(() => backend = v.trim());
                final loaded = await SourceRegistry.load(backendBase: backend);
                if (mounted) setState(() => sources = loaded);
                _save();
              },
              onRoi: (v) {
                setState(() => targetRoi = v.isFinite ? v.clamp(10, 100).toDouble() : 35.0);
                _save();
              },
              onPlan: (v) {
                setState(() => plan = v == UserPlan.proPlus ? UserPlan.pro : v);
                _save();
              },
              onSources: (v) {
                setState(() => sources = v);
                unawaited(SourceRegistry.save(v));
              },
              onHistory: _addHistory,
              onWatch: _addWatch,
              onRemoveWatch: (q) {
                setState(() => watchlist.removeWhere((e) => e.query == q));
                _save();
              },
              onAddFlip: (item) {
                setState(() => flips.insert(0, item));
                _save();
              },
              onRemoveFlip: (id) {
                setState(() => flips.removeWhere((e) => e.id == id));
                _save();
              },
              onUpdateFlip: (item) {
                final i = flips.indexWhere((e) => e.id == item.id);
                if (i < 0) return;
                setState(() => flips[i] = item);
                _save();
              },
            ),
    );
  }
}

class _FastShell extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final UserPlan plan;
  final List<FlipItem> flips;
  final List<WatchItem> watchlist;
  final List<String> history;
  final List<PriceSource> sources;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<String> onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlan;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<String> onRemoveWatch;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<String> onRemoveFlip;
  final ValueChanged<FlipItem> onUpdateFlip;

  const _FastShell({
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.plan,
    required this.flips,
    required this.watchlist,
    required this.history,
    required this.sources,
    required this.onLanguage,
    required this.onBackend,
    required this.onRoi,
    required this.onPlan,
    required this.onSources,
    required this.onHistory,
    required this.onWatch,
    required this.onRemoveWatch,
    required this.onAddFlip,
    required this.onRemoveFlip,
    required this.onUpdateFlip,
  });

  @override
  State<_FastShell> createState() => _FastShellState();
}

class _FastShellState extends State<_FastShell> {
  int tab = 0;
  bool _opening = false;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String _lastShared = '';
  DateTime? _lastSharedAt;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _startShares();
  }

  void _startShares() {
    try {
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleShare, onError: (_) {});
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final initial = await ReceiveSharingIntent.instance.getInitialMedia();
          if (initial.isNotEmpty) _handleShare(initial);
          await ReceiveSharingIntent.instance.reset();
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _handleShare(List<SharedMediaFile> items) {
    if (!mounted || items.isEmpty) return;
    SharedMediaFile? text;
    for (final item in items) {
      final mime = item.mimeType ?? '';
      if (item.type == SharedMediaType.text || item.type == SharedMediaType.url || mime.startsWith('text/')) {
        text = item;
        break;
      }
    }
    if (text == null) return;
    final q = extractSharedQuery(text.path).trim();
    if (q.isEmpty) return;
    final now = DateTime.now();
    if (_lastShared.toLowerCase() == q.toLowerCase() && _lastSharedAt != null && now.difference(_lastSharedAt!).inSeconds < 4) return;
    _lastShared = q;
    _lastSharedAt = now;
    unawaited(_openCheck(q));
  }

  Future<bool> _openCheck(String query) async {
    if (_opening || !mounted || query.trim().isEmpty) return false;
    _opening = true;
    try {
      final again = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FastCheckPage(
            english: widget.english,
            initialQuery: query.trim(),
            targetRoi: widget.targetRoi,
            plan: widget.plan,
            sources: widget.sources,
            onHistory: widget.onHistory,
            onWatch: widget.onWatch,
            onAddFlip: widget.onAddFlip,
            onRemoveFlip: widget.onRemoveFlip,
          ),
        ),
      );
      return again == true;
    } finally {
      _opening = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _scanSession() async {
    var keepGoing = true;
    while (mounted && keepGoing) {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
      );
      if (!mounted || code == null || code.trim().isEmpty) return;
      keepGoing = await _openCheck(code.trim());
    }
  }

  Future<void> _search(String q) async {
    final again = await _openCheck(q);
    if (again && mounted) await _scanSession();
  }

  Future<void> _openWatchlist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: SafeArea(
            child: WatchlistPage(
              english: widget.english,
              plan: widget.plan,
              watchlist: widget.watchlist,
              onOpen: (q) async {
                Navigator.pop(context);
                await _search(q);
              },
              onRemove: widget.onRemoveWatch,
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          english: widget.english,
          backend: widget.backend,
          targetRoi: widget.targetRoi,
          plan: widget.plan,
          sources: widget.sources,
          onLanguage: widget.onLanguage,
          onBackend: widget.onBackend,
          onRoi: widget.onRoi,
          onPlanPreview: widget.onPlan,
          onSources: widget.onSources,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _FastHome(
        english: widget.english,
        plan: widget.plan,
        history: widget.history,
        savedCount: widget.watchlist.length,
        openFlipCount: widget.flips.where((e) => e.status != 'Sold').length,
        onScan: _scanSession,
        onSearch: _search,
        onSaved: _openWatchlist,
        onSettings: _openSettings,
      ),
      FlipsPage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        onUpdate: widget.onUpdateFlip,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: _scanSession,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(t('SCANNEN', 'SCAN'), style: const TextStyle(fontWeight: FontWeight.w900)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt_rounded),
            label: t('Prüfen', 'Check'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: t('Meine Flips', 'My flips'),
          ),
        ],
      ),
    );
  }
}

class _FastHome extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<String> history;
  final int savedCount;
  final int openFlipCount;
  final VoidCallback onScan;
  final ValueChanged<String> onSearch;
  final VoidCallback onSaved;
  final VoidCallback onSettings;

  const _FastHome({
    required this.english,
    required this.plan,
    required this.history,
    required this.savedCount,
    required this.openFlipCount,
    required this.onScan,
    required this.onSearch,
    required this.onSaved,
    required this.onSettings,
  });

  @override
  State<_FastHome> createState() => _FastHomeState();
}

class _FastHomeState extends State<_FastHome> {
  final query = TextEditingController();
  String t(String de, String en) => widget.english ? en : de;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void _submit() {
    final q = query.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('FlipRadar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
            ),
            Badge(
              isLabelVisible: widget.savedCount > 0,
              label: Text('${widget.savedCount}'),
              child: IconButton.filledTonal(
                tooltip: t('Merkliste', 'Saved'),
                onPressed: widget.onSaved,
                icon: const Icon(Icons.bookmark_outline_rounded),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: t('Einstellungen', 'Settings'),
              onPressed: widget.onSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          t('Lohnt sich das?', 'Worth buying?'),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.0),
        ),
        const SizedBox(height: 7),
        Text(
          t('Scannen. Preis eingeben. Antwort bekommen.', 'Scan. Enter price. Get the answer.'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF737786)),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 86,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF24234A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            onPressed: widget.onScan,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 31),
                const SizedBox(width: 13),
                Text(t('JETZT SCANNEN', 'SCAN NOW'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          controller: query,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t('Produkt, Modell oder EAN suchen', 'Search product, model or EAN'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: _submit, icon: const Icon(Icons.arrow_forward_rounded)),
          ),
        ),
        const SizedBox(height: 13),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onSaved,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.ios_share_rounded, size: 19, color: Color(0xFF4E50D8)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    t('Online-Angebot? Teilen → FlipRadar', 'Online listing? Share → FlipRadar'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF4E50D8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.history.isNotEmpty) ...[
          const SizedBox(height: 23),
          Text(t('Zuletzt geprüft', 'Recent'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.history.take(3).map((q) => ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(q, overflow: TextOverflow.ellipsis),
                  ),
                  onPressed: () => widget.onSearch(q),
                )).toList(),
          ),
        ],
        if (widget.openFlipCount > 0) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF767A88)),
              const SizedBox(width: 8),
              Text(
                t('${widget.openFlipCount} offene Flips', '${widget.openFlipCount} open flips'),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF767A88)),
              ),
            ],
          ),
        ],
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 30),
          SponsoredSlot(english: widget.english, placement: 'fast_home_tail'),
        ],
      ],
    );
  }
}

enum _FastDecision { waiting, buy, negotiate, skip }

class FastCheckPage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<String> onRemoveFlip;

  const FastCheckPage({
    super.key,
    required this.english,
    required this.initialQuery,
    required this.targetRoi,
    required this.plan,
    required this.sources,
    required this.onHistory,
    required this.onWatch,
    required this.onAddFlip,
    required this.onRemoveFlip,
  });

  @override
  State<FastCheckPage> createState() => _FastCheckPageState();
}

class _FastCheckPageState extends State<FastCheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '0');
  final buyFocus = FocusNode();
  bool loading = false;
  bool searched = false;
  bool showManual = false;
  bool showDetails = false;
  int _searchToken = 0;
  List<SourceListing> listings = [];

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.initialQuery.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (query.text.isNotEmpty) unawaited(_search());
    });
  }

  @override
  void dispose() {
    query.dispose();
    buy.dispose();
    manualSell.dispose();
    costs.dispose();
    buyFocus.dispose();
    super.dispose();
  }

  double _value(TextEditingController c) => parseMoneyInput(c.text);

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty || loading) return;
    widget.onHistory(q);
    final token = ++_searchToken;
    setState(() {
      loading = true;
      searched = true;
      listings = [];
      manualSell.clear();
      showManual = false;
    });

    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    final batches = await Future.wait(direct.map((source) async {
      try {
        return await SourceRegistry.fetch(source, q);
      } catch (_) {
        return <SourceListing>[];
      }
    }));
    if (!mounted || token != _searchToken) return;

    final deduped = <String, SourceListing>{};
    for (final item in batches.expand((e) => e)) {
      if (!item.total.isFinite || item.total <= 0) continue;
      final key = item.url.trim().isNotEmpty
          ? '${item.sourceId}|${item.url.trim()}'
          : '${item.sourceId}|${item.title.toLowerCase()}|${item.total.toStringAsFixed(2)}';
      deduped[key] = item;
    }
    final all = deduped.values.toList()..sort((a, b) => a.total.compareTo(b.total));
    setState(() {
      listings = all;
      loading = false;
      if (_resaleValues(all).isEmpty) showManual = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && buy.text.isEmpty) buyFocus.requestFocus();
    });
  }

  List<double> _resaleValues([List<SourceListing>? input]) => (input ?? listings)
      .where((e) => e.role == 'resale' || e.role == 'local')
      .map((e) => e.total)
      .where((e) => e > 0 && e.isFinite)
      .toList();

  List<double> _retailValues() => listings
      .where((e) => e.role == 'retail' || e.role == 'refurb')
      .map((e) => e.total)
      .where((e) => e > 0 && e.isFinite)
      .toList();

  List<double> _buybackValues() => listings
      .where((e) => e.role == 'buyback')
      .map((e) => e.total)
      .where((e) => e > 0 && e.isFinite)
      .toList();

  double? _median(List<double> raw) {
    if (raw.isEmpty) return null;
    final values = [...raw]..sort();
    final mid = values.length ~/ 2;
    return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
  }

  List<double> _clean(List<double> raw) {
    final values = [...raw]..sort();
    if (values.length < 5) return values;
    final med = _median(values);
    if (med == null || med <= 0) return values;
    final filtered = values.where((v) => v >= med * 0.60 && v <= med * 1.60).toList();
    return filtered.length >= 3 ? filtered : values;
  }

  double? get resaleMedian => _median(_clean(_resaleValues()));
  double? get retailMedian => _median(_clean(_retailValues()));
  double? get buybackMedian => _median(_clean(_buybackValues()));

  double? get targetSell {
    final manual = _value(manualSell);
    if (manual > 0) return manual;
    final med = resaleMedian;
    return med == null ? null : med * 0.90;
  }

  double get extraCosts => _value(costs);

  double? get maxBuy {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    return math.max(0, (sell - extraCosts) / (1 + widget.targetRoi / 100));
  }

  double? get profit {
    final sell = targetSell;
    final price = _value(buy);
    if (sell == null || price <= 0) return null;
    return sell - price - extraCosts;
  }

  double? get roi {
    final p = profit;
    final price = _value(buy);
    if (p == null || price <= 0) return null;
    return p / price * 100;
  }

  _FastDecision get decision {
    final max = maxBuy;
    final price = _value(buy);
    if (max == null || price <= 0) return _FastDecision.waiting;
    if (price <= max) return _FastDecision.buy;
    if (price <= max * 1.15) return _FastDecision.negotiate;
    return _FastDecision.skip;
  }

  int get confidenceLevel {
    if (_value(manualSell) > 0) return 0;
    final values = _clean(_resaleValues());
    final med = _median(values);
    if (values.isEmpty || med == null || med <= 0) return 0;
    final spread = (values.last - values.first) / med;
    if (values.length >= 8 && spread <= .30) return 3;
    if (values.length >= 4 && spread <= .60) return 2;
    return 1;
  }

  double? get negotiationOffer {
    final max = maxBuy;
    final asking = _value(buy);
    if (max == null || max <= 0 || asking <= max) return null;
    final raw = math.min(max * .97, asking * .90);
    return math.max(5, (raw / 5).floor() * 5.0);
  }

  List<String> get riskTips {
    final q = query.text.toLowerCase();
    if (q.contains('iphone') || q.contains('smartphone') || q.contains('galaxy') || q.contains('pixel')) {
      return widget.english
          ? ['Activation/iCloud lock', 'IMEI & network', 'Battery, display & cameras']
          : ['iCloud-/Aktivierungssperre', 'IMEI & Netz', 'Akku, Display & Kameras'];
    }
    if (q.contains('macbook') || q.contains('laptop') || q.contains('notebook')) {
      return widget.english
          ? ['Battery health', 'MDM/BIOS lock', 'Display, ports & charger']
          : ['Akkuzustand', 'MDM-/BIOS-Sperre', 'Display, Anschlüsse & Netzteil'];
    }
    if (q.contains('playstation') || q.contains('ps5') || q.contains('xbox') || q.contains('switch')) {
      return widget.english
          ? ['HDMI/disc drive', 'Controller & ports', 'Console/account ban']
          : ['HDMI/Laufwerk', 'Controller & Anschlüsse', 'Konsolen-/Account-Ban'];
    }
    if (q.contains('sneaker') || q.contains('jordan') || q.contains('yeezy') || q.contains('dunk')) {
      return widget.english
          ? ['Authenticity', 'Exact size/model', 'Sole & condition']
          : ['Echtheit', 'Exakte Größe/Variante', 'Sohle & Zustand'];
    }
    return widget.english
        ? ['Exact model/variant', 'Defects & missing parts', 'Serial/authenticity if relevant']
        : ['Exaktes Modell/Variante', 'Defekte & fehlendes Zubehör', 'Seriennummer/Echtheit falls relevant'];
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Link konnte nicht geöffnet werden.', 'Could not open link.'))));
      }
    }
  }

  Future<void> _openEbaySold() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    await _launch(Uri.https('www.ebay.de', '/sch/i.html', {
      '_nkw': q,
      'LH_Sold': '1',
      'LH_Complete': '1',
    }));
  }

  Future<void> _openSource(PriceSource source) async {
    final uri = Uri.tryParse(source.searchUrl(query.text.trim()));
    if (uri != null) await _launch(uri);
  }

  Future<void> _openListing(SourceListing listing) async {
    final uri = Uri.tryParse(listing.url.trim());
    if (uri != null && uri.host.isNotEmpty) await _launch(uri);
  }

  void _saveWatch() {
    final q = query.text.trim();
    if (q.isEmpty) return;
    widget.onWatch(WatchItem(query: q, maxBuy: maxBuy ?? 0, createdAt: DateTime.now()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Gemerkte Deals findest du oben beim Lesezeichen.', 'Saved deal added.'))));
  }

  void _saveFlip() {
    final q = query.text.trim();
    final sell = targetSell;
    final price = _value(buy);
    if (q.isEmpty || sell == null || price <= 0) return;
    final item = FlipItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: q,
      buy: price,
      sell: sell,
      costs: extraCosts,
      status: 'Bought',
      source: 'FlipRadar',
      createdAt: DateTime.now(),
    );
    widget.onAddFlip(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Als gekauft gespeichert.', 'Saved as bought.')),
        action: SnackBarAction(label: t('RÜCKGÄNGIG', 'UNDO'), onPressed: () => widget.onRemoveFlip(item.id)),
      ),
    );
  }

  Future<void> _copyOffer() async {
    final offer = negotiationOffer;
    if (offer == null) return;
    final text = widget.english
        ? 'Hi, would ${euro(offer)} work? I could buy it soon.'
        : 'Hallo, wären ${euro(offer)} okay? Ich könnte zeitnah kaufen bzw. abholen.';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Nachricht kopiert.', 'Message copied.'))));
  }

  @override
  Widget build(BuildContext context) {
    final max = maxBuy;
    final sell = targetSell;
    final p = profit;
    final r = roi;
    final enabled = widget.sources.where((s) => s.enabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Deal-Check', 'Deal check'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: t('Echte eBay-Verkäufe', 'eBay sold listings'),
            onPressed: query.text.trim().isEmpty ? null : _openEbaySold,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(t('NÄCHSTEN ARTIKEL SCANNEN', 'SCAN NEXT ITEM'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
        children: [
          TextField(
            controller: query,
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: t('Artikel', 'Item'),
              hintText: t('Modell, Produktname oder EAN', 'Model, product or EAN'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: loading ? null : _search, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: buy,
            focusNode: buyFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              setState(() {});
              if (decision != _FastDecision.waiting) HapticFeedback.selectionClick();
            },
            decoration: InputDecoration(
              labelText: t('Was sollst du zahlen?', 'What would you pay?'),
              hintText: '0,00',
              suffixText: '€',
              prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                const SizedBox(width: 9),
                Text(t('Markt wird geprüft …', 'Checking market …'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF747886))),
              ],
            ),
          ],
          if (searched && !loading) ...[
            const SizedBox(height: 14),
            if (sell == null) ...[
              _MissingValueCard(
                english: widget.english,
                retail: retailMedian,
                onEbaySold: _openEbaySold,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: manualSell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: 'z. B. 250',
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
              ),
            ] else ...[
              _FastDecisionCard(
                english: widget.english,
                decision: decision,
                maxBuy: max,
                sell: sell,
                profit: p,
                roi: r,
              ),
              if (negotiationOffer != null && (decision == _FastDecision.negotiate || decision == _FastDecision.skip)) ...[
                const SizedBox(height: 9),
                _OfferCard(english: widget.english, offer: negotiationOffer!, onCopy: _copyOffer),
              ],
              if (decision == _FastDecision.buy || decision == _FastDecision.negotiate) ...[
                const SizedBox(height: 9),
                _RiskStrip(english: widget.english, tips: riskTips),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveWatch,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(t('Merken', 'Save')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _value(buy) > 0 ? _saveFlip : null,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(t('Gekauft', 'Bought')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            ExpansionTile(
              initiallyExpanded: false,
              onExpansionChanged: (v) => setState(() => showDetails = v),
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              leading: const Icon(Icons.tune_rounded),
              title: Text(t('Details', 'Details'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(t('Nur wenn du genauer prüfen willst', 'Only if you want to dig deeper'), style: const TextStyle(fontSize: 11.5)),
              children: [
                if (sell != null) ...[
                  _DetailRow(label: t('Konservativer Verkauf', 'Conservative sale'), value: euro(sell)),
                  if (resaleMedian != null) _DetailRow(label: t('Aktive Angebote Median', 'Active asking median'), value: euro(resaleMedian!)),
                  if (retailMedian != null) _DetailRow(label: t('Neupreis-Referenz', 'Retail reference'), value: euro(retailMedian!)),
                  if (buybackMedian != null) _DetailRow(label: t('Sofort-Ankauf', 'Instant buyback'), value: euro(buybackMedian!)),
                  _DetailRow(label: t('Vergleiche', 'Comparable listings'), value: '${_clean(_resaleValues()).length}'),
                  _DetailRow(label: t('Datenqualität', 'Data quality'), value: _confidenceText()),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: costs,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                    helperText: t('z. B. Versand, Gebühren, Fahrt', 'e.g. shipping, fees, travel'),
                    suffixText: '€',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openEbaySold,
                    icon: const Icon(Icons.history_rounded),
                    label: Text(t('eBay: VERKAUFTE ARTIKEL PRÜFEN', 'eBay: CHECK SOLD ITEMS')),
                  ),
                ),
                if (listings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...listings.take(6).map((item) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.sourceName),
                        trailing: Text(euro(item.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                        onTap: item.url.trim().isEmpty ? null : () => _openListing(item),
                      )),
                ],
                if (enabled.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: enabled.take(8).map((s) => SourcePillButton(source: s, onTap: () => _openSource(s))).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  t(
                    'Aktive Angebote sind keine bestätigten Verkäufe. FlipRadar nutzt deshalb 10 % Sicherheitsabstand. Für echte Verkäufe nutze den eBay-Button oben.',
                    'Active listings are not confirmed sales. FlipRadar applies a 10% safety margin. Use the eBay button above to inspect sold items.',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF777B88), height: 1.35),
                ),
              ],
            ),
            if (widget.plan == UserPlan.free) ...[
              const SizedBox(height: 18),
              SponsoredSlot(english: widget.english, placement: 'fast_result_tail'),
            ],
          ],
        ],
      ),
    );
  }

  String _confidenceText() {
    if (_value(manualSell) > 0) return t('manuell', 'manual');
    switch (confidenceLevel) {
      case 3:
        return t('gut', 'good');
      case 2:
        return t('okay', 'fair');
      case 1:
        return t('unsicher', 'low');
      default:
        return t('keine', 'none');
    }
  }
}

class _FastDecisionCard extends StatelessWidget {
  final bool english;
  final _FastDecision decision;
  final double? maxBuy;
  final double? sell;
  final double? profit;
  final double? roi;

  const _FastDecisionCard({
    required this.english,
    required this.decision,
    required this.maxBuy,
    required this.sell,
    required this.profit,
    required this.roi,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    Color bg;
    Color fg;
    IconData icon;
    String title;
    String sub;
    switch (decision) {
      case _FastDecision.buy:
        bg = const Color(0xFF0D4939);
        fg = Colors.white;
        icon = Icons.thumb_up_alt_rounded;
        title = t('KAUFEN', 'BUY');
        sub = t('Preis passt.', 'Price works.');
        break;
      case _FastDecision.negotiate:
        bg = const Color(0xFFFFE7AA);
        fg = const Color(0xFF654800);
        icon = Icons.handshake_outlined;
        title = t('VERHANDELN', 'NEGOTIATE');
        sub = t('Fast gut – etwas runter.', 'Close – negotiate down.');
        break;
      case _FastDecision.skip:
        bg = const Color(0xFFFFE1DE);
        fg = const Color(0xFF8B3028);
        icon = Icons.block_rounded;
        title = t('LASSEN', 'SKIP');
        sub = t('Zu teuer.', 'Too expensive.');
        break;
      case _FastDecision.waiting:
        bg = const Color(0xFFEAEAFB);
        fg = const Color(0xFF373873);
        icon = Icons.keyboard_rounded;
        title = t('PREIS EINGEBEN', 'ENTER PRICE');
        sub = t('Dann kommt sofort die Antwort.', 'Then you get the answer.');
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(27)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 34, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: fg)),
                    Text(sub, style: TextStyle(fontSize: 12.5, color: fg.withValues(alpha: .78))),
                  ],
                ),
              ),
            ],
          ),
          if (maxBuy != null && sell != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('MAXIMAL ZAHLEN', 'MAX BUY'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF777B88))),
                        Text(euro(maxBuy!), style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: Color(0xFF1F2128))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(t('Verkauf ca.', 'Sale est.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF777B88))),
                      Text(euro(sell!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            if (profit != null && roi != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: _FastMetric(label: t('Gewinn ca.', 'Profit est.'), value: euro(profit!), color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _FastMetric(label: 'ROI', value: '${roi!.toStringAsFixed(0)} %', color: fg)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FastMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FastMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: color == Colors.white ? .13 : .65), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 10.5, color: color.withValues(alpha: .72))),
        ],
      ),
    );
  }
}

class _MissingValueCard extends StatelessWidget {
  final bool english;
  final double? retail;
  final VoidCallback onEbaySold;

  const _MissingValueCard({required this.english, required this.retail, required this.onEbaySold});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF2D5), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('MARKTWERT NOCH NICHT SICHER', 'MARKET VALUE NOT CLEAR YET'), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6A4B00))),
          if (retail != null) ...[
            const SizedBox(height: 4),
            Text(t('Neupreis-Referenz: ${euro(retail!)}', 'Retail reference: ${euro(retail!)}'), style: const TextStyle(fontSize: 12, color: Color(0xFF7C632B))),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onEbaySold,
              icon: const Icon(Icons.history_rounded),
              label: Text(t('VERKAUFTE EBAY-ARTIKEL ANSEHEN', 'VIEW SOLD EBAY ITEMS')),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final bool english;
  final double offer;
  final VoidCallback onCopy;

  const _OfferCard({required this.english, required this.offer, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF4DB), borderRadius: BorderRadius.circular(19)),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF986300)),
          const SizedBox(width: 9),
          Expanded(child: Text(english ? 'Try ${euro(offer)}' : 'Versuch ${euro(offer)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          TextButton(onPressed: onCopy, child: Text(english ? 'Copy' : 'Kopieren')),
        ],
      ),
    );
  }
}

class _RiskStrip extends StatelessWidget {
  final bool english;
  final List<String> tips;

  const _RiskStrip({required this.english, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE6E7EF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(english ? 'Before paying' : 'Vor dem Bezahlen', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tips.take(3).map((e) => Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(e, style: const TextStyle(fontSize: 11.5)),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6F7380)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
