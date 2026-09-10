import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'source_registry.dart';

part 'v06_home.dart';
part 'v06_check.dart';
part 'v06_watch_flips.dart';
part 'v06_sources_more.dart';
part 'v06_scanner_helpers.dart';

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
        name: j['name']?.toString() ?? 'Item',
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

  const WatchItem({
    required this.query,
    required this.maxBuy,
    required this.createdAt,
  });

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
  bool onboardingDone = false;
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

    for (final raw in p.getStringList('flips_v06') ?? <String>[]) {
      try {
        storedFlips.add(FlipItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    for (final raw in p.getStringList('watch_v06') ?? <String>[]) {
      try {
        storedWatch.add(WatchItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }

    final loadedBackend = p.getString('backend_v06') ?? p.getString('backend_v05') ?? '';
    final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
    if (!mounted) return;

    setState(() {
      english = p.getBool('english_v06') ?? p.getBool('english_v05') ?? false;
      onboardingDone = p.getBool('onboarding_v06') ?? p.getBool('onboarding_v05') ?? false;
      backend = loadedBackend;
      targetRoi = p.getDouble('roi_v06') ?? p.getDouble('roi_v05') ?? 35;
      plan = UserPlan.values[(p.getInt('plan_preview_v06') ?? 0).clamp(0, UserPlan.values.length - 1)];
      flips = storedFlips;
      watchlist = storedWatch;
      history = p.getStringList('history_v06') ?? <String>[];
      sources = loadedSources;
      loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('english_v06', english);
    await p.setBool('onboarding_v06', onboardingDone);
    await p.setString('backend_v06', backend);
    await p.setDouble('roi_v06', targetRoi);
    await p.setInt('plan_preview_v06', plan.index);
    await p.setStringList('flips_v06', flips.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('watch_v06', watchlist.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('history_v06', history.take(12).toList());
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
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5146E5),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );

    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : onboardingDone
              ? Shell(
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
                )
              : OnboardingPage(
                  english: english,
                  onLanguage: (v) {
                    setState(() => english = v);
                    _save();
                  },
                  onFinish: () {
                    setState(() => onboardingDone = true);
                    _save();
                  },
                ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final bool english;
  final ValueChanged<bool> onLanguage;
  final VoidCallback onFinish;

  const OnboardingPage({
    super.key,
    required this.english,
    required this.onLanguage,
    required this.onFinish,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int page = 0;
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    final pages = [
      (
        Icons.qr_code_scanner,
        t('Scannen. Fertig.', 'Scan. Done.'),
        t(
          'Barcode scannen oder Produktnamen eintippen. Kein Konto, kein Technik-Wissen nötig.',
          'Scan a barcode or type a product name. No account or technical knowledge needed.',
        ),
      ),
      (
        Icons.auto_awesome,
        t('Nur das Wichtige sehen', 'Only see what matters'),
        t(
          'FlipRadar fasst Preise zusammen und erklärt BUY MAX, Gewinn und ROI in normaler Sprache.',
          'FlipRadar summarizes prices and explains BUY MAX, profit and ROI in plain language.',
        ),
      ),
      (
        Icons.notifications_active_outlined,
        t('Gute Deals wiederfinden', 'Never lose a good deal'),
        t(
          'Speichere interessante Produkte. Später können Preisalarme automatisch prüfen, ob dein Zielpreis erreicht ist.',
          'Save interesting products. Later, price alerts can automatically check whether your target is reached.',
        ),
      ),
    ];
    final current = pages[page];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('FlipRadar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('DE')),
                      ButtonSegment(value: true, label: Text('EN')),
                    ],
                    selected: {widget.english},
                    onSelectionChanged: (v) => widget.onLanguage(v.first),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 54,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(current.$1, size: 58),
              ),
              const SizedBox(height: 28),
              Text(current.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(current.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.45)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == page ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == page ? Theme.of(context).colorScheme.primary : Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (page < pages.length - 1) {
                      setState(() => page++);
                    } else {
                      widget.onFinish();
                    }
                  },
                  child: Text(page < pages.length - 1 ? t('Weiter', 'Continue') : t('Loslegen', 'Get started')),
                ),
              ),
            ],
          ),
        ),
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
  String pendingQuery = '';
  String t(String de, String en) => widget.english ? en : de;

  void goCheck([String query = '']) {
    setState(() {
      pendingQuery = query;
      tab = 1;
    });
  }

  Future<void> openSources() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourcesPage(
          english: widget.english,
          backend: widget.backend,
          sources: widget.sources,
          onChanged: widget.onSources,
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
        onCheck: goCheck,
        onScan: () async {
          final code = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
          );
          if (code != null && code.isNotEmpty) goCheck(code);
        },
        onSources: openSources,
      ),
      CheckPage(
        key: ValueKey('$pendingQuery-${widget.sources.length}-${widget.backend}-${widget.plan.index}'),
        english: widget.english,
        initialQuery: pendingQuery,
        targetRoi: widget.targetRoi,
        plan: widget.plan,
        sources: widget.sources,
        onAddFlip: widget.onAddFlip,
        onHistory: widget.onHistory,
        onWatch: widget.onWatch,
      ),
      WatchPage(
        english: widget.english,
        plan: widget.plan,
        items: widget.watchlist,
        onCheck: goCheck,
        onRemove: widget.onRemoveWatch,
      ),
      FlipsPage(
        english: widget.english,
        flips: widget.flips,
        onUpdate: widget.onUpdateFlip,
      ),
      MorePage(
        english: widget.english,
        backend: widget.backend,
        targetRoi: widget.targetRoi,
        plan: widget.plan,
        sourceCount: widget.sources.where((e) => e.enabled).length,
        onLanguage: widget.onLanguage,
        onBackend: widget.onBackend,
        onRoi: widget.onRoi,
        onPlanPreview: widget.onPlanPreview,
        onSources: openSources,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('Start', 'Home')),
          NavigationDestination(icon: const Icon(Icons.fact_check_outlined), selectedIcon: const Icon(Icons.fact_check), label: t('Prüfen', 'Check')),
          NavigationDestination(icon: const Icon(Icons.bookmark_border), selectedIcon: const Icon(Icons.bookmark), label: t('Merkliste', 'Watch')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: 'Flips'),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: t('Mehr', 'More')),
        ],
      ),
    );
  }
}
