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

/// Parses the formats people commonly type in Germany and English locales.
/// Examples: 1299,99 · 1.299,99 · 1,299.99 · 1299.99.
double parseMoneyInput(String raw) {
  var value = raw
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (value.isEmpty) return 0;

  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    if (comma > dot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      value = value.replaceAll(',', '');
    }
  } else if (comma >= 0) {
    final decimals = value.length - comma - 1;
    value = decimals == 3 && comma > 0
        ? value.replaceAll(',', '')
        : value.replaceAll(',', '.');
  } else if (dot >= 0) {
    final decimals = value.length - dot - 1;
    if (decimals == 3 && dot > 0) value = value.replaceAll('.', '');
  }

  final parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite || parsed < 0) return 0;
  return parsed;
}

String _limitSharedQuery(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 140
      ? normalized
      : normalized.substring(0, 140).trim();
}

String _decodeSharedSegment(String segment) {
  try {
    return Uri.decodeComponent(segment)
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  } catch (_) {
    return segment
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

bool _isUsefulSharedText(String value) {
  final compact = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9äöüÄÖÜß]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (compact.length < 4) return false;
  final lower = compact.toLowerCase();
  const generic = {
    'gerade bei kleinanzeigen gefunden wie findest du das',
    'bei kleinanzeigen gefunden wie findest du das',
    'wie findest du das',
    'schau dir diesen artikel an',
    'sieh dir diesen artikel an',
    'check out this item',
    'look at this item',
  };
  return !generic.contains(lower);
}

/// Extracts a useful product query from text shared by marketplace/browser apps.
/// Marketing boilerplate and URLs are ignored; known marketplace URL shapes are
/// used as a fallback when the shared text contains no product title.
String extractSharedQuery(String raw) {
  final source = raw.trim();
  if (source.isEmpty) return '';

  final urlMatch = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(source);
  final urlText = urlMatch?.group(0)?.replaceAll(RegExp(r'[),.;]+$'), '');
  final uri = urlText == null ? null : Uri.tryParse(urlText);

  if (uri != null) {
    for (final key in const ['q', '_nkw', 'query', 'keyword', 'keywords']) {
      final value = uri.queryParameters[key]?.trim();
      if (value != null && value.length >= 3) {
        return _limitSharedQuery(value);
      }
    }
  }

  var cleaned = source.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), ' ');
  cleaned = cleaned
      .replaceAll(
        RegExp(r'gerade\s+bei\s+#?kleinanzeigen\s+gefunden\.?', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'wie\s+findest\s+du\s+das\??', caseSensitive: false), ' ')
      .replaceAll(
        RegExp(r'^(schau\s+dir|sieh\s+dir|check\s+out|look\s+at)\s+', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\b\d[\d.\s]*(?:,\d{1,2})?\s*€'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (_isUsefulSharedText(cleaned)) return _limitSharedQuery(cleaned);

  if (uri != null) {
    final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();
    final host = uri.host.toLowerCase();

    if (host.contains('kleinanzeigen')) {
      final index = segments.indexWhere((e) => e.toLowerCase() == 's-anzeige');
      if (index >= 0 && index + 1 < segments.length) {
        final title = _decodeSharedSegment(segments[index + 1]);
        if (_isUsefulSharedText(title)) return _limitSharedQuery(title);
      }
    }

    if (host.contains('ebay.')) {
      final index = segments.indexWhere((e) => e.toLowerCase() == 'itm');
      if (index >= 0) {
        for (final segment in segments.skip(index + 1)) {
          final title = _decodeSharedSegment(segment);
          if (RegExp(r'^\d+$').hasMatch(title)) continue;
          if (_isUsefulSharedText(title)) return _limitSharedQuery(title);
        }
      }
    }

    final dp = segments.indexWhere((e) => e.toLowerCase() == 'dp');
    if (dp >= 0 && dp + 1 < segments.length) {
      final asin = segments[dp + 1].trim();
      if (RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(asin)) {
        return asin.toUpperCase();
      }
    }

    const ignored = {'itm', 'p', 'dp', 's', 'product', 'produkte', 'anzeige', 'anzeigen', 'search'};
    for (final segment in segments.reversed) {
      final decoded = _decodeSharedSegment(segment);
      if (decoded.length < 5 ||
          RegExp(r'^\d+$').hasMatch(decoded) ||
          ignored.contains(decoded.toLowerCase())) {
        continue;
      }
      if (_isUsefulSharedText(decoded)) return _limitSharedQuery(decoded);
    }
  }

  return _limitSharedQuery(source);
}

class FlipRadarFinalApp extends StatefulWidget {
  const FlipRadarFinalApp({super.key});

  @override
  State<FlipRadarFinalApp> createState() => _FlipRadarFinalAppState();
}

class _FlipRadarFinalAppState extends State<FlipRadarFinalApp> {
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
      final flipRaw = p.getStringList('flips_v09') ??
          p.getStringList('flips_v08') ??
          p.getStringList('flips_v07') ??
          <String>[];
      final watchRaw = p.getStringList('watch_v09') ??
          p.getStringList('watch_v08') ??
          p.getStringList('watch_v07') ??
          <String>[];

      for (final raw in flipRaw) {
        try {
          final item = FlipItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (item.name.trim().isNotEmpty &&
              item.buy.isFinite &&
              item.sell.isFinite &&
              item.costs.isFinite &&
              item.buy >= 0 &&
              item.sell >= 0 &&
              item.costs >= 0) {
            storedFlips.add(item);
          }
        } catch (_) {}
      }
      for (final raw in watchRaw) {
        try {
          final item = WatchItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (item.query.trim().isNotEmpty && item.maxBuy.isFinite && item.maxBuy >= 0) {
            storedWatch.add(item);
          }
        } catch (_) {}
      }

      final loadedBackend = p.getString('backend_v09') ??
          p.getString('backend_v08') ??
          p.getString('backend_v07') ??
          '';
      final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
      if (!mounted) return;
      final rawRoi = p.getDouble('roi_v09') ??
          p.getDouble('roi_v08') ??
          p.getDouble('roi_v07') ??
          35;
      final rawPlan = p.getInt('plan_preview_v09') ??
          p.getInt('plan_preview_v08') ??
          p.getInt('plan_preview_v07') ??
          0;
      final loadedHistory = p.getStringList('history_v09') ??
          p.getStringList('history_v08') ??
          p.getStringList('history_v07') ??
          <String>[];

      setState(() {
        english = p.getBool('english_v09') ??
            p.getBool('english_v08') ??
            p.getBool('english_v07') ??
            false;
        backend = loadedBackend.trim();
        targetRoi = rawRoi.isFinite ? rawRoi.clamp(10, 100).toDouble() : 35;
        final planIndex = rawPlan.clamp(0, UserPlan.values.length - 1);
        plan = UserPlan.values[planIndex] == UserPlan.proPlus
            ? UserPlan.pro
            : UserPlan.values[planIndex];
        flips = storedFlips;
        watchlist = storedWatch;
        history = loadedHistory
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .take(12)
            .toList();
        sources = loadedSources;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = await SourceRegistry.load();
      if (!mounted) return;
      setState(() {
        sources = fallback;
        loading = false;
      });
    }
  }

  void _scheduleSave() {
    _saveQueue = _saveQueue.then((_) => _saveNow()).catchError((_) {});
  }

  Future<void> _saveNow() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('english_v09', english);
    await p.setString('backend_v09', backend);
    await p.setDouble('roi_v09', targetRoi);
    await p.setInt('plan_preview_v09', plan.index);
    await p.setStringList('flips_v09', flips.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('watch_v09', watchlist.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('history_v09', history.take(12).toList());
  }

  Future<void> _reloadSources() async {
    final loaded = await SourceRegistry.load(backendBase: backend);
    if (!mounted) return;
    setState(() => sources = loaded);
  }

  void _addHistory(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    setState(() {
      history.removeWhere((x) => x.toLowerCase() == value.toLowerCase());
      history.insert(0, value);
      if (history.length > 12) history = history.take(12).toList();
    });
    _scheduleSave();
  }

  void _addWatch(WatchItem item) {
    setState(() {
      watchlist.removeWhere((x) => x.query.toLowerCase() == item.query.toLowerCase());
      watchlist.insert(0, item);
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5CE2),
      brightness: Brightness.light,
      surface: const Color(0xFFF7F8FC),
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE8E9F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF5B5CE2), width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );

    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _FinalShell(
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
                _scheduleSave();
              },
              onBackend: (v) async {
                setState(() => backend = v.trim());
                _scheduleSave();
                await _reloadSources();
              },
              onRoi: (v) {
                final safe = v.isFinite ? v.clamp(10, 100).toDouble() : 35.0;
                setState(() => targetRoi = safe);
                _scheduleSave();
              },
              onPlanPreview: (v) {
                setState(() => plan = v == UserPlan.proPlus ? UserPlan.pro : v);
                _scheduleSave();
              },
              onSources: (v) {
                setState(() => sources = v);
                unawaited(SourceRegistry.save(v));
              },
              onHistory: _addHistory,
              onWatch: _addWatch,
              onRemoveWatch: (q) {
                setState(() => watchlist.removeWhere((x) => x.query == q));
                _scheduleSave();
              },
              onAddFlip: (f) {
                setState(() => flips.insert(0, f));
                _scheduleSave();
              },
              onRemoveFlip: (id) {
                setState(() => flips.removeWhere((x) => x.id == id));
                _scheduleSave();
              },
              onUpdateFlip: (f) {
                final i = flips.indexWhere((x) => x.id == f.id);
                if (i < 0) return;
                setState(() => flips[i] = f);
                _scheduleSave();
              },
            ),
    );
  }
}

class _FinalShell extends StatefulWidget {
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
  final ValueChanged<UserPlan> onPlanPreview;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<String> onRemoveWatch;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<String> onRemoveFlip;
  final ValueChanged<FlipItem> onUpdateFlip;

  const _FinalShell({
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
    required this.onPlanPreview,
    required this.onSources,
    required this.onHistory,
    required this.onWatch,
    required this.onRemoveWatch,
    required this.onAddFlip,
    required this.onRemoveFlip,
    required this.onUpdateFlip,
  });

  @override
  State<_FinalShell> createState() => _FinalShellState();
}

class _FinalShellState extends State<_FinalShell> {
  int tab = 0;
  bool _openingCheck = false;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  String _lastSharedQuery = '';
  DateTime? _lastSharedAt;
  String? _pendingSharedQuery;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _startShareReceiver();
  }

  void _startShareReceiver() {
    try {
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        _handleSharedMedia,
        onError: (_) {},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final initial = await ReceiveSharingIntent.instance.getInitialMedia();
          if (initial.isNotEmpty) _handleSharedMedia(initial);
          await ReceiveSharingIntent.instance.reset();
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _handleSharedMedia(List<SharedMediaFile> items) {
    if (!mounted || items.isEmpty) return;
    SharedMediaFile? textItem;
    for (final item in items) {
      final mime = item.mimeType ?? '';
      if (item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url ||
          mime.startsWith('text/')) {
        textItem = item;
        break;
      }
    }
    if (textItem == null) return;
    final q = _queryFromShared(textItem.path);
    if (q.isEmpty) return;

    final now = DateTime.now();
    if (_lastSharedQuery.toLowerCase() == q.toLowerCase() &&
        _lastSharedAt != null &&
        now.difference(_lastSharedAt!).inSeconds < 4) {
      return;
    }
    _lastSharedQuery = q;
    _lastSharedAt = now;
    _pendingSharedQuery = q;
    Future.microtask(_drainSharedQuery);
  }

  String _queryFromShared(String raw) => _limitQuery(extractSharedQuery(raw));

  void _drainSharedQuery() {
    if (!mounted || _pendingSharedQuery == null) return;
    if (_openingCheck) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    final q = _pendingSharedQuery!;
    _pendingSharedQuery = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openCheck(q));
    });
  }

  String _limitQuery(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 140 ? normalized : normalized.substring(0, 140).trim();
  }

  Future<void> openCheck([String query = '']) async {
    if (_openingCheck || !mounted) return;
    _openingCheck = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FinalCheckPage(
            english: widget.english,
            initialQuery: query,
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
    } finally {
      _openingCheck = false;
      final hasPendingShare = _pendingSharedQuery != null;
      if (mounted) setState(() {});
      if (mounted && hasPendingShare) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _drainSharedQuery());
      }
    }
  }

  Future<void> scanAndCheck() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
    );
    if (code != null && code.trim().isNotEmpty && mounted) {
      await openCheck(code.trim());
    }
  }

  Future<void> openSettings() async {
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
          onPlanPreview: widget.onPlanPreview,
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
      HomePage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        watchlist: widget.watchlist,
        history: widget.history,
        sources: widget.sources,
        onSearch: openCheck,
        onScan: scanAndCheck,
        onSettings: openSettings,
      ),
      WatchlistPage(
        english: widget.english,
        plan: widget.plan,
        watchlist: widget.watchlist,
        onOpen: openCheck,
        onRemove: widget.onRemoveWatch,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.radar_outlined),
            selectedIcon: const Icon(Icons.radar),
            label: t('Prüfen', 'Check'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: t('Merkliste', 'Saved'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Flips',
          ),
        ],
      ),
    );
  }
}

enum _FinalDealDecision { waiting, buy, negotiate, skip }

class FinalCheckPage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
  final ValueChanged<String> onHistory;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<String> onRemoveFlip;

  const FinalCheckPage({
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
  State<FinalCheckPage> createState() => _FinalCheckPageState();
}

class _FinalCheckPageState extends State<FinalCheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '0');
  bool loading = false;
  bool searched = false;
  bool showManual = false;
  bool showCosts = false;
  int _searchToken = 0;
  String _lastSearchedQuery = '';
  List<SourceListing> listings = [];

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.initialQuery.trim());
    if (query.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    query.dispose();
    buy.dispose();
    manualSell.dispose();
    costs.dispose();
    super.dispose();
  }

  double value(TextEditingController c) => parseMoneyInput(c.text);

  void _queryChanged(String raw) {
    final now = raw.trim();
    if (!searched || now == _lastSearchedQuery) return;
    _searchToken++;
    setState(() {
      loading = false;
      searched = false;
      listings = [];
      showManual = false;
      manualSell.clear();
    });
  }

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty || loading) return;
    FocusScope.of(context).unfocus();
    widget.onHistory(q);
    final token = ++_searchToken;
    _lastSearchedQuery = q;
    setState(() {
      loading = true;
      searched = true;
      listings = [];
      showManual = false;
      manualSell.clear();
    });

    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    final batches = await Future.wait(
      direct.map((source) async {
        try {
          return await SourceRegistry.fetch(source, q);
        } catch (_) {
          return <SourceListing>[];
        }
      }),
    );
    if (!mounted || token != _searchToken) return;

    if (query.text.trim() != q) {
      setState(() {
        loading = false;
        searched = false;
        listings = [];
      });
      return;
    }

    final deduped = <String, SourceListing>{};
    for (final item in batches.expand((x) => x)) {
      if (item.total <= 0 || !item.total.isFinite) continue;
      final identity = item.url.trim().isNotEmpty
          ? '${item.sourceId}|${item.url.trim()}'
          : '${item.sourceId}|${item.title.toLowerCase().trim()}|${item.total.toStringAsFixed(2)}';
      deduped[identity] = item;
    }
    final all = deduped.values.toList()..sort((a, b) => a.total.compareTo(b.total));
    setState(() {
      listings = all;
      loading = false;
      if (_resaleValues(all).isEmpty) showManual = true;
    });
  }

  List<double> _resaleValues([List<SourceListing>? input]) =>
      (input ?? listings)
          .where((e) => e.role == 'resale' || e.role == 'local')
          .map((e) => e.total)
          .where((v) => v > 0 && v.isFinite)
          .toList();

  List<double> _retailValues() => listings
      .where((e) => e.role == 'retail' || e.role == 'refurb')
      .map((e) => e.total)
      .where((v) => v > 0 && v.isFinite)
      .toList();

  List<double> _buybackValues() => listings
      .where((e) => e.role == 'buyback')
      .map((e) => e.total)
      .where((v) => v > 0 && v.isFinite)
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
    final base = _median(values);
    if (base == null || base <= 0) return values;
    final filtered = values.where((v) => v >= base * 0.6 && v <= base * 1.6).toList();
    return filtered.length >= 3 ? filtered : values;
  }

  double? get resaleMedian => _median(_clean(_resaleValues()));
  double? get retailMedian => _median(_clean(_retailValues()));
  double? get buybackMedian => _median(_clean(_buybackValues()));
  bool get usesManualSell => value(manualSell) > 0;

  double? get targetSell {
    final manual = value(manualSell);
    if (manual > 0) return manual;
    final resale = resaleMedian;
    return resale == null ? null : resale * 0.90;
  }

  double get extraCosts => value(costs);

  double? get maxBuy {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    final result = (sell - extraCosts) / (1 + widget.targetRoi / 100);
    return math.max(0, result);
  }

  double? get profit {
    final sell = targetSell;
    final price = value(buy);
    if (sell == null || price <= 0) return null;
    return sell - price - extraCosts;
  }

  double? get roi {
    final p = profit;
    final price = value(buy);
    if (p == null || price <= 0) return null;
    return p / price * 100;
  }

  _FinalDealDecision get decision {
    final max = maxBuy;
    final price = value(buy);
    if (max == null || price <= 0) return _FinalDealDecision.waiting;
    if (price <= max) return _FinalDealDecision.buy;
    if (price <= max * 1.15) return _FinalDealDecision.negotiate;
    return _FinalDealDecision.skip;
  }

  int get confidenceLevel {
    if (usesManualSell) return 0;
    final values = _clean(_resaleValues());
    final med = _median(values);
    if (values.isEmpty || med == null || med <= 0) return 0;
    final spread = (values.last - values.first) / med;
    if (values.length >= 8 && spread <= 0.30) return 3;
    if (values.length >= 4 && spread <= 0.60) return 2;
    return 1;
  }

  String get confidenceText {
    if (usesManualSell) return t('manuell', 'manual');
    if (confidenceLevel >= 3) return t('gut', 'good');
    if (confidenceLevel == 2) return t('okay', 'fair');
    if (confidenceLevel == 1) return t('unsicher', 'low');
    return t('keine', 'none');
  }

  double? get negotiationOffer {
    final max = maxBuy;
    final asking = value(buy);
    if (max == null || max <= 0 || asking <= max) return null;
    final raw = math.min(max * 0.97, asking * 0.90);
    return math.max(5, (raw / 5).floor() * 5.0);
  }

  List<String> get riskTips {
    final q = query.text.toLowerCase();
    if (q.contains('iphone') || q.contains('smartphone') || q.contains('galaxy') || q.contains('pixel')) {
      return widget.english
          ? ['Activation/iCloud lock', 'IMEI & network status', 'Battery, cameras & display']
          : ['iCloud-/Aktivierungssperre', 'IMEI & Netz prüfen', 'Akku, Kameras & Display'];
    }
    if (q.contains('macbook') || q.contains('laptop') || q.contains('notebook')) {
      return widget.english
          ? ['Battery condition', 'MDM/BIOS lock', 'Display, ports & charger']
          : ['Akkuzustand', 'MDM-/BIOS-Sperre', 'Display, Anschlüsse & Netzteil'];
    }
    if (q.contains('ps5') || q.contains('playstation') || q.contains('xbox') || q.contains('switch')) {
      return widget.english
          ? ['HDMI/disc drive', 'Controller & ports', 'Account/console ban']
          : ['HDMI/Laufwerk', 'Controller & Anschlüsse', 'Account-/Konsolen-Ban'];
    }
    if (q.contains('sneaker') || q.contains('jordan') || q.contains('yeezy') || q.contains('dunk')) {
      return widget.english
          ? ['Authenticity', 'Exact size/model', 'Soles, stains & wear']
          : ['Echtheit', 'Exakte Größe/Variante', 'Sohle, Flecken & Verschleiß'];
    }
    if (q.contains('kamera') || q.contains('camera') || q.contains('canon') || q.contains('nikon') || q.contains('sony alpha')) {
      return widget.english
          ? ['Sensor/lens condition', 'Shutter count', 'Battery & charger']
          : ['Sensor/Objektiv', 'Auslösungen', 'Akku & Ladegerät'];
    }
    return widget.english
        ? ['Exact model/variant', 'Defects & missing parts', 'Serial/authenticity if relevant']
        : ['Exaktes Modell/Variante', 'Defekte & fehlendes Zubehör', 'Seriennummer/Echtheit falls relevant'];
  }

  Future<void> _launch(Uri? uri) async {
    if (uri == null || !{'http', 'https'}.contains(uri.scheme.toLowerCase()) || uri.host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Link ist ungültig.', 'Invalid link.'))));
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Webseite konnte nicht geöffnet werden.', 'Could not open website.'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Webseite konnte nicht geöffnet werden.', 'Could not open website.'))));
      }
    }
  }

  Future<void> _openSource(PriceSource source) async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    await _launch(Uri.tryParse(source.searchUrl(q)));
  }

  Future<void> _openListing(SourceListing item) async {
    await _launch(Uri.tryParse(item.url.trim()));
  }

  void _saveWatch() {
    final q = query.text.trim();
    if (q.isEmpty) return;
    widget.onWatch(WatchItem(query: q, maxBuy: maxBuy ?? 0, createdAt: DateTime.now()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Auf der Merkliste gespeichert.', 'Saved to your list.'))),
    );
  }

  void _saveFlip() {
    final q = query.text.trim();
    final sell = targetSell;
    final price = value(buy);
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
        action: SnackBarAction(
          label: t('RÜCKGÄNGIG', 'UNDO'),
          onPressed: () => widget.onRemoveFlip(item.id),
        ),
      ),
    );
  }

  Future<void> _copyNegotiation() async {
    final offer = negotiationOffer;
    if (offer == null) return;
    final q = query.text.trim();
    final text = widget.english
        ? 'Hi, would ${euro(offer)} work for $q? I could buy it soon.'
        : 'Hallo, wären ${euro(offer)} für $q okay? Ich könnte zeitnah kaufen bzw. abholen.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Nachricht kopiert.', 'Message copied.'))));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((s) => s.enabled).toList();
    final resale = resaleMedian;
    final retail = retailMedian;
    final max = maxBuy;
    final p = profit;
    final r = roi;

    return Scaffold(
      appBar: AppBar(title: Text(t('Deal prüfen', 'Check deal'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          _QaStepCard(
            number: '1',
            title: t('Artikel', 'Item'),
            color: const Color(0xFFEDEDFC),
            child: Column(
              children: [
                TextField(
                  controller: query,
                  enabled: !loading,
                  onChanged: _queryChanged,
                  onSubmitted: (_) => _search(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t('Modell, Produktname oder EAN', 'Model, product or EAN'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: loading ? null : _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 9),
                  const LinearProgressIndicator(minHeight: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _QaStepCard(
            number: '2',
            title: t('Dein Preis', 'Your price'),
            color: const Color(0xFFFFF3D9),
            child: TextField(
              controller: buy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '0,00',
                suffixText: '€',
                prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),
              ),
            ),
          ),
          if (searched) ...[
            const SizedBox(height: 12),
            if (resale != null && !usesManualSell)
              _QaMarketCard(
                english: widget.english,
                askingMedian: resale,
                conservativeSell: resale * 0.90,
                count: _clean(_resaleValues()).length,
                confidenceLevel: confidenceLevel,
              )
            else if (retail != null && !usesManualSell)
              _QaRetailCard(
                english: widget.english,
                retailMedian: retail,
                onManual: () => setState(() => showManual = true),
              )
            else if (!usesManualSell)
              _QaNoDataCard(
                english: widget.english,
                sources: enabled,
                onOpenSource: _openSource,
                onManual: () => setState(() => showManual = true),
              ),
            if (resale != null && !usesManualSell) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => showManual = !showManual),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(t('Eigenen Verkaufspreis nutzen', 'Use your own sale price')),
                ),
              ),
            ],
            if (showManual || usesManualSell) ...[
              const SizedBox(height: 6),
              TextField(
                controller: manualSell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: resale == null ? 'z. B. 250' : euro(resale * 0.90),
                  suffixText: '€',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _QaDecisionCard(
              english: widget.english,
              decision: decision,
              maxBuy: max,
              sell: targetSell,
              profit: p,
              roi: r,
              targetRoi: widget.targetRoi,
              confidence: confidenceText,
              costsAdded: extraCosts > 0,
            ),
            if ((decision == _FinalDealDecision.negotiate || decision == _FinalDealDecision.skip) && negotiationOffer != null) ...[
              const SizedBox(height: 10),
              _QaNegotiationCard(english: widget.english, offer: negotiationOffer!, onCopy: _copyNegotiation),
            ],
            if (decision == _FinalDealDecision.buy || decision == _FinalDealDecision.negotiate) ...[
              const SizedBox(height: 10),
              _QaRiskCard(english: widget.english, tips: riskTips),
            ],
            if (targetSell != null) ...[
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
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: value(buy) > 0 ? _saveFlip : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(t('Gekauft', 'Bought')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(t('Warum diese Empfehlung?', 'Why this recommendation?'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(t('Details nur bei Bedarf', 'Details only if needed'), style: const TextStyle(fontSize: 12)),
              children: [
                if (!showCosts)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => showCosts = true),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(t('Versand/Gebühren hinzufügen', 'Add shipping/fees')),
                    ),
                  ),
                if (showCosts)
                  TextField(
                    controller: costs,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                      suffixText: '€',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                const SizedBox(height: 10),
                _QaDetailsGrid(
                  english: widget.english,
                  resaleMedian: resale,
                  retailMedian: retail,
                  buybackMedian: buybackMedian,
                  costs: extraCosts,
                  targetRoi: widget.targetRoi,
                  confidence: confidenceText,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    usesManualSell
                        ? t('Die Entscheidung nutzt deinen eigenen Verkaufspreis.', 'The decision uses your own sale price.')
                        : t('Aktive Angebote sind keine bestätigten Verkäufe. Deshalb rechnet FlipRadar mit 10 % Sicherheitsabstand.', 'Active listings are not confirmed sales. FlipRadar therefore applies a 10% safety margin.'),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF747987), height: 1.4),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(t('Preise & Quellen', 'Prices & sources'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                listings.isEmpty
                    ? t('${enabled.length} Webseiten verfügbar', '${enabled.length} websites available')
                    : t('${listings.length} automatische Treffer', '${listings.length} automatic results'),
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                if (listings.isNotEmpty)
                  ...listings.take(12).map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEDEDFC),
                          child: Text(item.sourceName.isEmpty ? '?' : item.sourceName.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item.sourceName} · ${_roleLabel(item.role)}${item.condition.isEmpty ? '' : ' · ${item.condition}'}'),
                        trailing: Text(euro(item.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                        onTap: item.url.trim().isEmpty ? null : () => _openListing(item),
                      )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: enabled.take(8).map((s) => SourcePillButton(source: s, onTap: () => _openSource(s))).toList(),
                ),
              ],
            ),
            if (widget.plan == UserPlan.free) ...[
              const SizedBox(height: 14),
              SponsoredSlot(english: widget.english, placement: 'result_tail'),
            ],
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF276AA5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('Artikel suchen → Preis eingeben → Entscheidung.', 'Search item → enter price → get decision.'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF315B7E), fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'resale':
        return t('Wiederverkauf', 'resale');
      case 'local':
        return t('lokal', 'local');
      case 'retail':
        return t('Neupreis', 'retail');
      case 'refurb':
        return t('refurbished', 'refurbished');
      case 'buyback':
        return t('Sofort-Ankauf', 'buyback');
      default:
        return t('Referenz', 'reference');
    }
  }
}

class _QaStepCard extends StatelessWidget {
  final String number;
  final String title;
  final Color color;
  final Widget child;

  const _QaStepCard({required this.number, required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _QaMarketCard extends StatelessWidget {
  final bool english;
  final double askingMedian;
  final double conservativeSell;
  final int count;
  final int confidenceLevel;

  const _QaMarketCard({
    required this.english,
    required this.askingMedian,
    required this.conservativeSell,
    required this.count,
    required this.confidenceLevel,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F2),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFC9EEDF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.show_chart_rounded, color: Color(0xFF0A8F6A), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Konservativer Verkauf', 'Conservative sale'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF4C7568))),
                Text(euro(conservativeSell), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF145E49))),
                Text(t('Angebote im Median ${euro(askingMedian)}', 'Asking median ${euro(askingMedian)}'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF66867B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < confidenceLevel ? const Color(0xFF0A8F6A) : const Color(0xFFC7D8D2),
                      ),
                    )),
              ),
              const SizedBox(height: 4),
              Text(t('$count Vergleiche', '$count comps'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF5A756C))),
            ],
          ),
        ],
      ),
    );
  }
}

class _QaRetailCard extends StatelessWidget {
  final bool english;
  final double retailMedian;
  final VoidCallback onManual;

  const _QaRetailCard({required this.english, required this.retailMedian, required this.onManual});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Neupreis-Referenz: ${euro(retailMedian)}', 'Retail reference: ${euro(retailMedian)}'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('Nicht automatisch als Gebrauchtwert benutzt.', 'Not automatically used as resale value.'), style: const TextStyle(fontSize: 12, color: Color(0xFF775B2A))),
          TextButton.icon(onPressed: onManual, icon: const Icon(Icons.edit_outlined), label: Text(t('Verkaufspreis eingeben', 'Enter sale price'))),
        ],
      ),
    );
  }
}

class _QaNoDataCard extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<PriceSource> onOpenSource;
  final VoidCallback onManual;

  const _QaNoDataCard({required this.english, required this.sources, required this.onOpenSource, required this.onManual});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Noch keine automatischen Wiederverkaufsdaten', 'No automatic resale data yet'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(t('Quelle öffnen oder Verkaufspreis selbst eingeben.', 'Open a source or enter a sale price.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF6F7482))),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sources.take(4).map((s) => SourcePillButton(source: s, onTap: () => onOpenSource(s))).toList(),
          ),
          TextButton.icon(onPressed: onManual, icon: const Icon(Icons.edit_outlined), label: Text(t('Verkaufspreis eingeben', 'Enter sale price'))),
        ],
      ),
    );
  }
}

class _QaDecisionCard extends StatelessWidget {
  final bool english;
  final _FinalDealDecision decision;
  final double? maxBuy;
  final double? sell;
  final double? profit;
  final double? roi;
  final double targetRoi;
  final String confidence;
  final bool costsAdded;

  const _QaDecisionCard({
    required this.english,
    required this.decision,
    required this.maxBuy,
    required this.sell,
    required this.profit,
    required this.roi,
    required this.targetRoi,
    required this.confidence,
    required this.costsAdded,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    late Color bg;
    late Color fg;
    late IconData icon;
    late String title;
    late String subtitle;
    switch (decision) {
      case _FinalDealDecision.buy:
        bg = const Color(0xFF103F35);
        fg = Colors.white;
        icon = Icons.thumb_up_alt_rounded;
        title = t('KAUFEN', 'BUY');
        subtitle = t('Passt zu deinem Gewinnziel.', 'Fits your profit target.');
        break;
      case _FinalDealDecision.negotiate:
        bg = const Color(0xFFFFE9B8);
        fg = const Color(0xFF684A00);
        icon = Icons.handshake_outlined;
        title = t('VERHANDELN', 'NEGOTIATE');
        subtitle = t('Fast gut. Preis runterhandeln.', 'Almost good. Negotiate it down.');
        break;
      case _FinalDealDecision.skip:
        bg = const Color(0xFFFFE4E1);
        fg = const Color(0xFF8D2F28);
        icon = Icons.block_rounded;
        title = t('LASSEN', 'SKIP');
        subtitle = t('Zu teuer für dein Ziel.', 'Too expensive for your target.');
        break;
      case _FinalDealDecision.waiting:
        bg = const Color(0xFFEDEDFC);
        fg = const Color(0xFF3F3F79);
        icon = Icons.arrow_upward_rounded;
        title = sell == null ? t('MARKTWERT FEHLT', 'NEED MARKET VALUE') : t('PREIS EINGEBEN', 'ENTER PRICE');
        subtitle = sell == null ? t('Verkaufspreis ergänzen oder Quelle prüfen.', 'Add sale price or check a source.') : t('Dann kommt sofort die Entscheidung.', 'Then you get the decision instantly.');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(27)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: fg, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                    Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.82), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          if (maxBuy != null && sell != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('MAXIMAL ZAHLEN', 'MAX BUY'), style: const TextStyle(fontSize: 11, color: Color(0xFF7A7E8C), fontWeight: FontWeight.w900)),
                        Text(euro(maxBuy!), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF20222A))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(t('Verkauf ca.', 'Sale est.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8C))),
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
                  Expanded(child: _QaMini(label: t('Gewinn ca.', 'Profit est.'), value: euro(profit!), color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _QaMini(label: 'ROI', value: '${roi!.toStringAsFixed(0)} %', color: fg)),
                  const SizedBox(width: 8),
                  Expanded(child: _QaMini(label: t('Daten', 'Data'), value: confidence, color: fg)),
                ],
              ),
            ],
          ],
          const SizedBox(height: 7),
          Text(
            costsAdded ? t('Zusatzkosten eingerechnet.', 'Extra costs included.') : t('Ohne zusätzliche Versand-/Verkaufskosten.', 'Excludes extra shipping/selling costs.'),
            style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.62)),
          ),
        ],
      ),
    );
  }
}

class _QaMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QaMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: color == Colors.white ? 0.12 : 0.6), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color.withValues(alpha: 0.72), fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _QaNegotiationCard extends StatelessWidget {
  final bool english;
  final double offer;
  final VoidCallback onCopy;

  const _QaNegotiationCard({required this.english, required this.offer, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF5DD), borderRadius: BorderRadius.circular(21)),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF9C6500)),
          const SizedBox(width: 10),
          Expanded(child: Text(english ? 'Try ${euro(offer)}' : 'Versuch ${euro(offer)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          TextButton(onPressed: onCopy, child: Text(english ? 'Copy' : 'Kopieren')),
        ],
      ),
    );
  }
}

class _QaRiskCard extends StatelessWidget {
  final bool english;
  final List<String> tips;

  const _QaRiskCard({required this.english, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE8E9EF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(english ? 'Before you buy' : 'Vor Kauf kurz prüfen', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...tips.take(3).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 17, color: Color(0xFF0A8F6A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _QaDetailsGrid extends StatelessWidget {
  final bool english;
  final double? resaleMedian;
  final double? retailMedian;
  final double? buybackMedian;
  final double costs;
  final double targetRoi;
  final String confidence;

  const _QaDetailsGrid({
    required this.english,
    required this.resaleMedian,
    required this.retailMedian,
    required this.buybackMedian,
    required this.costs,
    required this.targetRoi,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Wiederverkauf', 'Resale asking'), value: resaleMedian == null ? '–' : euro(resaleMedian!))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Datenlage', 'Confidence'), value: confidence)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Neupreis', 'Retail'), value: retailMedian == null ? '–' : euro(retailMedian!))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Sofort-Ankauf', 'Buyback'), value: buybackMedian == null ? '–' : euro(buybackMedian!))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: MetricBox(label: t('Zusatzkosten', 'Extra costs'), value: euro(costs))),
            const SizedBox(width: 8),
            Expanded(child: MetricBox(label: t('Gewinnziel', 'Target ROI'), value: '${targetRoi.toStringAsFixed(0)} %')),
          ],
        ),
      ],
    );
  }
}
