import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'source_registry.dart';

part 'v07_home.dart';
part 'v07_check.dart';
part 'v07_library.dart';
part 'v07_settings.dart';
part 'v07_widgets.dart';

enum UserPlan { free, pro, proPlus }

class FlipItem {
  final String id;
  final String name;
  final double buy;
  final double sell;
  final double costs;
  final String status;
  final String source;
  final DateTime createdAt;

  const FlipItem({
    required this.id,
    required this.name,
    required this.buy,
    required this.sell,
    required this.costs,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  double get profit => sell - buy - costs;
  double get roi => buy <= 0 ? 0 : profit / buy * 100;

  FlipItem copyWith({String? status, double? sell}) => FlipItem(
        id: id,
        name: name,
        buy: buy,
        sell: sell ?? this.sell,
        costs: costs,
        status: status ?? this.status,
        source: source,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buy': buy,
        'sell': sell,
        'costs': costs,
        'status': status,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FlipItem.fromJson(Map<String, dynamic> j) => FlipItem(
        id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? 'Artikel',
        buy: (j['buy'] as num?)?.toDouble() ?? 0,
        sell: (j['sell'] as num?)?.toDouble() ?? 0,
        costs: (j['costs'] as num?)?.toDouble() ?? 0,
        status: j['status']?.toString() ?? 'Bought',
        source: j['source']?.toString() ?? 'Manual',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class WatchItem {
  final String query;
  final double maxBuy;
  final DateTime createdAt;

  const WatchItem({required this.query, required this.maxBuy, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'query': query,
        'maxBuy': maxBuy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WatchItem.fromJson(Map<String, dynamic> j) => WatchItem(
        query: j['query']?.toString() ?? '',
        maxBuy: (j['maxBuy'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class FlipRadarApp extends StatefulWidget {
  const FlipRadarApp({super.key});

  @override
  State<FlipRadarApp> createState() => _FlipRadarAppState();
}

class _FlipRadarAppState extends State<FlipRadarApp> {
  bool loading = true;
  bool english = false;
  String backend = '';
  double targetRoi = 35;
  UserPlan plan = UserPlan.free;
  List<FlipItem> flips = [];
  List<WatchItem> watchlist = [];
  List<String> history = [];
  List<PriceSource> sources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final storedFlips = <FlipItem>[];
    final storedWatch = <WatchItem>[];

    final flipRaw = p.getStringList('flips_v07') ?? p.getStringList('flips_v06') ?? <String>[];
    final watchRaw = p.getStringList('watch_v07') ?? p.getStringList('watch_v06') ?? <String>[];

    for (final raw in flipRaw) {
      try {
        storedFlips.add(FlipItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    for (final raw in watchRaw) {
      try {
        storedWatch.add(WatchItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }

    final loadedBackend = p.getString('backend_v07') ?? p.getString('backend_v06') ?? '';
    final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
    if (!mounted) return;

    setState(() {
      english = p.getBool('english_v07') ?? p.getBool('english_v06') ?? false;
      backend = loadedBackend;
      targetRoi = p.getDouble('roi_v07') ?? p.getDouble('roi_v06') ?? 35;
      plan = UserPlan.values[(p.getInt('plan_preview_v07') ?? 0).clamp(0, UserPlan.values.length - 1)];
      flips = storedFlips;
      watchlist = storedWatch;
      history = p.getStringList('history_v07') ?? p.getStringList('history_v06') ?? <String>[];
      sources = loadedSources;
      loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('english_v07', english);
    await p.setString('backend_v07', backend);
    await p.setDouble('roi_v07', targetRoi);
    await p.setInt('plan_preview_v07', plan.index);
    await p.setStringList('flips_v07', flips.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('watch_v07', watchlist.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('history_v07', history.take(12).toList());
  }

  Future<void> _reloadSources() async {
    final loaded = await SourceRegistry.load(backendBase: backend);
    if (!mounted) return;
    setState(() => sources = loaded);
  }

  void _addHistory(String q) {
    final value = q.trim();
    if (value.isEmpty) return;
    setState(() {
      history.removeWhere((x) => x.toLowerCase() == value.toLowerCase());
      history.insert(0, value);
      if (history.length > 12) history = history.take(12).toList();
    });
    _save();
  }

  void _addWatch(WatchItem item) {
    setState(() {
      watchlist.removeWhere((x) => x.query.toLowerCase() == item.query.toLowerCase());
      watchlist.insert(0, item);
    });
    _save();
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE8E9F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF5B5CE2), width: 1.6),
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
          : Shell(
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
                await _save();
                await _reloadSources();
              },
              onRoi: (v) {
                setState(() => targetRoi = v);
                _save();
              },
              onPlanPreview: (v) {
                setState(() => plan = v);
                _save();
              },
              onSources: (v) {
                setState(() => sources = v);
                SourceRegistry.save(v);
              },
              onHistory: _addHistory,
              onWatch: _addWatch,
              onRemoveWatch: (q) {
                setState(() => watchlist.removeWhere((x) => x.query == q));
                _save();
              },
              onAddFlip: (f) {
                setState(() => flips.insert(0, f));
                _save();
              },
              onUpdateFlip: (f) {
                final i = flips.indexWhere((x) => x.id == f.id);
                if (i < 0) return;
                setState(() => flips[i] = f);
                _save();
              },
            ),
    );
  }
}

class Shell extends StatefulWidget {
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
  final ValueChanged<FlipItem> onUpdateFlip;

  const Shell({
    super.key,
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
    required this.onUpdateFlip,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String t(String de, String en) => widget.english ? en : de;

  Future<void> openCheck([String query = '']) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckPage(
          english: widget.english,
          initialQuery: query,
          targetRoi: widget.targetRoi,
          plan: widget.plan,
          sources: widget.sources,
          onHistory: widget.onHistory,
          onWatch: widget.onWatch,
          onAddFlip: widget.onAddFlip,
        ),
      ),
    );
    if (mounted) setState(() {});
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
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: 'Flips',
          ),
        ],
      ),
    );
  }
}
