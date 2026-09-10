import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'source_registry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipRadarApp());
}

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

  factory FlipItem.fromJson(Map<String, dynamic> json) => FlipItem(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? 'Item',
        buy: (json['buy'] as num?)?.toDouble() ?? 0,
        sell: (json['sell'] as num?)?.toDouble() ?? 0,
        costs: (json['costs'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? 'Bought',
        source: json['source']?.toString() ?? 'Manual',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
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
  List<PriceSource> sources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final storedFlips = <FlipItem>[];
    for (final raw in p.getStringList('flips_v05') ?? <String>[]) {
      try {
        storedFlips.add(FlipItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    final loadedBackend = p.getString('backend_v05') ?? '';
    final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
    if (!mounted) return;
    setState(() {
      english = p.getBool('english_v05') ?? false;
      onboardingDone = p.getBool('onboarding_v05') ?? false;
      backend = loadedBackend;
      targetRoi = p.getDouble('roi_v05') ?? 35;
      plan = UserPlan.values[(p.getInt('plan_preview_v05') ?? 0).clamp(0, UserPlan.values.length - 1)];
      flips = storedFlips;
      sources = loadedSources;
      loading = false;
    });
  }

  Future<void> _saveCore() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('english_v05', english);
    await p.setBool('onboarding_v05', onboardingDone);
    await p.setString('backend_v05', backend);
    await p.setDouble('roi_v05', targetRoi);
    await p.setInt('plan_preview_v05', plan.index);
    await p.setStringList('flips_v05', flips.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _reloadSources() async {
    final loaded = await SourceRegistry.load(backendBase: backend);
    if (!mounted) return;
    setState(() => sources = loaded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5446E8),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
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
                  sources: sources,
                  onLanguage: (v) {
                    setState(() => english = v);
                    _saveCore();
                  },
                  onBackend: (v) async {
                    setState(() => backend = v.trim());
                    await _saveCore();
                    await _reloadSources();
                  },
                  onRoi: (v) {
                    setState(() => targetRoi = v);
                    _saveCore();
                  },
                  onPlanPreview: (v) {
                    setState(() => plan = v);
                    _saveCore();
                  },
                  onSources: (v) {
                    setState(() => sources = v);
                    SourceRegistry.save(v);
                  },
                  onAddFlip: (f) {
                    setState(() => flips.insert(0, f));
                    _saveCore();
                  },
                  onUpdateFlip: (f) {
                    final i = flips.indexWhere((x) => x.id == f.id);
                    if (i < 0) return;
                    setState(() => flips[i] = f);
                    _saveCore();
                  },
                )
              : OnboardingPage(
                  english: english,
                  onLanguage: (v) {
                    setState(() => english = v);
                    _saveCore();
                  },
                  onFinish: () {
                    setState(() => onboardingDone = true);
                    _saveCore();
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
    final cards = [
      (
        Icons.qr_code_scanner,
        t('1. Produkt scannen', '1. Scan a product'),
        t('Barcode scannen oder Produktnamen eingeben. Mehr musst du nicht wissen.', 'Scan a barcode or type a product name. That is all you need to know.'),
      ),
      (
        Icons.compare_arrows,
        t('2. Preise vergleichen', '2. Compare prices'),
        t('FlipRadar bündelt deine aktivierten Quellen und zeigt klar, wo Live-Daten direkt verfügbar sind.', 'FlipRadar groups your enabled sources and clearly shows where live in-app data is available.'),
      ),
      (
        Icons.check_circle_outline,
        t('3. Kaufen oder lassen', '3. Buy or skip'),
        t('Du siehst Zielverkauf, maximalen Einkaufspreis, Gewinn, ROI und Risiken in einfacher Sprache.', 'You see target sale price, max buy price, profit, ROI and risks in plain language.'),
      ),
    ];
    final current = cards[page];
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
                radius: 52,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(current.$1, size: 54),
              ),
              const SizedBox(height: 28),
              Text(current.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(current.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.45)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Container(
                  width: i == page ? 26 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == page ? Theme.of(context).colorScheme.primary : Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                )),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (page < 2) {
                      setState(() => page++);
                    } else {
                      widget.onFinish();
                    }
                  },
                  child: Text(page < 2 ? t('Weiter', 'Continue') : t('Loslegen', 'Get started')),
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
  final List<PriceSource> sources;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<String> onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlanPreview;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<FlipItem> onAddFlip;
  final ValueChanged<FlipItem> onUpdateFlip;

  const Shell({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.plan,
    required this.flips,
    required this.sources,
    required this.onLanguage,
    required this.onBackend,
    required this.onRoi,
    required this.onPlanPreview,
    required this.onSources,
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        sources: widget.sources,
        onCheck: goCheck,
        onScan: () async {
          final code = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)),
          );
          if (code != null && code.isNotEmpty) goCheck(code);
        },
        onSources: () => setState(() => tab = 2),
      ),
      CheckPage(
        key: ValueKey('$pendingQuery-${widget.sources.length}-${widget.backend}'),
        english: widget.english,
        initialQuery: pendingQuery,
        targetRoi: widget.targetRoi,
        sources: widget.sources,
        onAddFlip: widget.onAddFlip,
      ),
      SourcesPage(
        english: widget.english,
        backend: widget.backend,
        sources: widget.sources,
        onChanged: widget.onSources,
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
        onLanguage: widget.onLanguage,
        onBackend: widget.onBackend,
        onRoi: widget.onRoi,
        onPlanPreview: widget.onPlanPreview,
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
          NavigationDestination(icon: const Icon(Icons.hub_outlined), selectedIcon: const Icon(Icons.hub), label: t('Quellen', 'Sources')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: 'Flips'),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: t('Mehr', 'More')),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<FlipItem> flips;
  final List<PriceSource> sources;
  final ValueChanged<String> onCheck;
  final VoidCallback onScan;
  final VoidCallback onSources;

  const HomePage({
    super.key,
    required this.english,
    required this.plan,
    required this.flips,
    required this.sources,
    required this.onCheck,
    required this.onScan,
    required this.onSources,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  String t(String de, String en) => widget.english ? en : de;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final profit = sold.fold<double>(0, (a, b) => a + b.profit);
    final capital = widget.flips.where((e) => e.status != 'Sold').fold<double>(0, (a, b) => a + b.buy);
    final activeSources = widget.sources.where((e) => e.enabled).length;
    final planName = widget.plan == UserPlan.free ? 'FREE' : widget.plan == UserPlan.pro ? 'PRO' : 'PRO+';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(child: header('FlipRadar', t('Einfach prüfen. Sicherer entscheiden.', 'Check simply. Decide with confidence.'))),
            const SizedBox(width: 8),
            Chip(label: Text(planName, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1D1948), Color(0xFF5947EC)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              darkStat(t('Gewinn', 'Profit'), '${profit.toStringAsFixed(0)} €'),
              darkStat(t('Kapital', 'Capital'), '${capital.toStringAsFixed(0)} €'),
              darkStat(t('Quellen', 'Sources'), '$activeSources'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(t('Schnellstart', 'Quick start'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onCheck(v.trim());
          },
          decoration: InputDecoration(
            hintText: t('z. B. iPhone 15 Pro oder EAN', 'e.g. iPhone 15 Pro or EAN'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(onPressed: widget.onScan, icon: const Icon(Icons.qr_code_scanner)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  if (search.text.trim().isNotEmpty) widget.onCheck(search.text.trim());
                },
                icon: const Icon(Icons.price_check),
                label: Text(t('Preis prüfen', 'Check price')),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(onPressed: widget.onScan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')),
          ],
        ),
        const SizedBox(height: 20),
        _HowCard(
          number: '1',
          icon: Icons.qr_code_scanner,
          title: t('Scannen oder suchen', 'Scan or search'),
          text: t('Produktname, Modell oder Barcode reicht.', 'Product name, model or barcode is enough.'),
        ),
        const SizedBox(height: 8),
        _HowCard(
          number: '2',
          icon: Icons.compare_arrows,
          title: t('Quellen vergleichen', 'Compare sources'),
          text: t('$activeSources Quellen sind aktiv. Du siehst sofort, welche direkt Live-Preise liefern.', '$activeSources sources are enabled. You immediately see which provide live in-app prices.'),
          onTap: widget.onSources,
        ),
        const SizedBox(height: 8),
        _HowCard(
          number: '3',
          icon: Icons.thumb_up_alt_outlined,
          title: t('Kaufen oder lassen', 'Buy or skip'),
          text: t('BUY MAX, Gewinn und ROI werden ohne Fachsprache erklärt.', 'BUY MAX, profit and ROI are explained without technical jargon.'),
        ),
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 18),
          SponsoredSlot(english: widget.english),
        ],
      ],
    );
  }
}

class _HowCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  const _HowCard({required this.number, required this.icon, required this.title, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900))),
              const SizedBox(width: 12),
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(text, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckPage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final List<PriceSource> sources;
  final ValueChanged<FlipItem> onAddFlip;

  const CheckPage({
    super.key,
    required this.english,
    required this.initialQuery,
    required this.targetRoi,
    required this.sources,
    required this.onAddFlip,
  });

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final manualSell = TextEditingController();
  final costs = TextEditingController(text: '10');
  bool loading = false;
  bool searched = false;
  List<SourceListing> listings = [];
  final Map<String, String> errors = {};

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
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

  double parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      searched = true;
      listings = [];
      errors.clear();
    });
    final enabled = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    final collected = <SourceListing>[];
    for (final source in enabled) {
      try {
        collected.addAll(await SourceRegistry.fetch(source, q));
      } catch (_) {
        errors[source.id] = t('Keine Live-Antwort', 'No live response');
      }
    }
    if (!mounted) return;
    setState(() {
      listings = collected..sort((a, b) => a.total.compareTo(b.total));
      loading = false;
    });
  }

  double? get marketMedian {
    if (listings.isEmpty) return null;
    final values = listings.map((e) => e.total).where((v) => v > 0).toList()..sort();
    if (values.isEmpty) return null;
    final middle = values.length ~/ 2;
    return values.length.isOdd ? values[middle] : (values[middle - 1] + values[middle]) / 2;
  }

  double? get targetSell {
    final manual = parse(manualSell);
    if (manual > 0) return manual;
    return marketMedian;
  }

  double? get buyMax {
    final sell = targetSell;
    if (sell == null || sell <= 0) return null;
    final c = parse(costs);
    return math.max(0, (sell - c) / (1 + widget.targetRoi / 100));
  }

  Future<void> _open(PriceSource source) async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    await launchUrl(Uri.parse(source.searchUrl(q)), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((e) => e.enabled).toList();
    final median = marketMedian;
    final sell = targetSell;
    final b = parse(buy);
    final c = parse(costs);
    final profit = sell == null ? null : sell - b - c;
    final roi = profit == null || b <= 0 ? null : profit / b * 100;
    final max = buyMax;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Deal prüfen', 'Check a deal'), t('Ein Produkt rein. Eine klare Entscheidung raus.', 'One product in. One clear decision out.')),
        const SizedBox(height: 14),
        TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: t('Was möchtest du prüfen?', 'What do you want to check?'),
            hintText: t('Produkt, Modell, EAN oder ASIN', 'Product, model, EAN or ASIN'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : _search, icon: const Icon(Icons.compare_arrows), label: Text(loading ? t('Suche läuft…', 'Searching…') : t('Jetzt vergleichen', 'Compare now')))),
        const SizedBox(height: 12),
        if (enabled.isEmpty)
          infoBox(context, Icons.warning_amber_rounded, t('Keine Quelle aktiv. Öffne unten „Quellen“ und schalte mindestens eine Quelle ein.', 'No source enabled. Open Sources below and enable at least one source.'))
        else
          Text(t('${enabled.length} Quellen aktiv', '${enabled.length} sources enabled'), style: const TextStyle(color: Colors.black54)),
        if (searched) ...[
          const SizedBox(height: 18),
          if (median != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.bolt),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('Live-Auswertung', 'Live result'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                      const Chip(label: Text('LIVE')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: resultBox(t('Median', 'Median'), '${median.toStringAsFixed(0)} €')),
                      Expanded(child: resultBox('BUY MAX', max == null ? '–' : '${max.toStringAsFixed(0)} €')),
                      Expanded(child: resultBox(t('Treffer', 'Results'), '${listings.length}')),
                    ]),
                    const SizedBox(height: 8),
                    Text(t('BUY MAX = maximaler Einkaufspreis für dein Ziel von ${widget.targetRoi.toStringAsFixed(0)} % ROI.', 'BUY MAX = maximum purchase price for your ${widget.targetRoi.toStringAsFixed(0)}% ROI target.'), style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            )
          else
            infoBox(
              context,
              Icons.info_outline,
              t('Noch keine Live-Preise direkt in der App. Das ist kein Fehler: Quellen ohne freigeschaltete API bleiben trotzdem über ihre offizielle Live-Suche nutzbar.', 'No live prices inside the app yet. This is not an error: sources without an enabled API still work through their official live search.'),
            ),
          const SizedBox(height: 14),
          Text(t('Quellen', 'Sources'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...enabled.map((source) {
            final hits = listings.where((e) => e.sourceId == source.id).toList();
            final direct = source.canFetchInApp;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    sourceBadge(source),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(source.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                            hits.isNotEmpty
                                ? t('${hits.length} Live-Treffer · ab ${hits.first.total.toStringAsFixed(2)} €', '${hits.length} live results · from €${hits.first.total.toStringAsFixed(2)}')
                                : direct
                                    ? (errors[source.id] ?? t('Adapter verbunden · aktuell keine Treffer', 'Adapter connected · no results right now'))
                                    : t('Offizielle Live-Suche öffnen', 'Open official live search'),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(onPressed: () => _open(source), icon: const Icon(Icons.open_in_new), label: Text(t('Öffnen', 'Open'))),
                  ],
                ),
              ),
            );
          }),
          if (listings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(t('Günstigste Live-Treffer', 'Cheapest live results'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...listings.take(8).map((item) => Card(
                  child: ListTile(
                    title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${item.sourceName}${item.condition.isEmpty ? '' : ' · ${item.condition}'}'),
                    trailing: Text('${item.total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900)),
                    onTap: item.url.isEmpty ? null : () => launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
                  ),
                )),
          ],
          const SizedBox(height: 18),
          Text(t('Dein konkretes Angebot', 'Your actual deal'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: buy, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Einkauf €', 'Buy €')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: costs, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Kosten €', 'Costs €')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: manualSell, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Zielverkauf € (optional)', 'Target sale € (optional)'), helperText: t('Leer lassen = Live-Median verwenden', 'Leave empty = use live median'))),
          const SizedBox(height: 12),
          if (sell != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: resultBox(t('Zielverkauf', 'Target sale'), '${sell.toStringAsFixed(0)} €')),
                      Expanded(child: resultBox(t('Gewinn', 'Profit'), profit == null ? '–' : '${profit.toStringAsFixed(0)} €')),
                      Expanded(child: resultBox('ROI', roi == null ? '–' : '${roi.toStringAsFixed(1)} %')),
                    ]),
                    const SizedBox(height: 10),
                    if (b > 0 && max != null)
                      decisionBanner(context, b <= max, t),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: b <= 0
                            ? null
                            : () {
                                widget.onAddFlip(FlipItem(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  name: query.text.trim().isEmpty ? 'Item' : query.text.trim(),
                                  buy: b,
                                  sell: sell,
                                  costs: c,
                                  status: 'Bought',
                                  source: 'FlipRadar',
                                  createdAt: DateTime.now(),
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Zu Flips gespeichert', 'Saved to Flips'))));
                              },
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(t('Als Kauf speichern', 'Save as purchase')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class SourcesPage extends StatefulWidget {
  final bool english;
  final String backend;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;

  const SourcesPage({super.key, required this.english, required this.backend, required this.sources, required this.onChanged});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  late List<PriceSource> items;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
  }

  void save() => widget.onChanged([...items]);

  Future<void> _addCustom() async {
    final result = await showModalBottomSheet<PriceSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSourceSheet(english: widget.english),
    );
    if (result == null) return;
    if (items.any((e) => e.id == result.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Diese Quelle gibt es bereits.', 'This source already exists.'))));
      return;
    }
    setState(() => items.add(result));
    save();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = items.where((e) => e.enabled).length;
    final direct = items.where((e) => e.enabled && e.canFetchInApp).length;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Quellen', 'Sources'), t('Wie Steckdosen: einschalten, fertig.', 'Like switches: turn on and go.')),
        const SizedBox(height: 12),
        infoBox(
          context,
          Icons.lightbulb_outline,
          t('Grün = sofort nutzbar. „In-App Live“ bedeutet: FlipRadar kann Preise direkt einlesen. „Website“ bedeutet: ein Tippen öffnet die offizielle aktuelle Suche.', 'Green = ready now. “In-app live” means FlipRadar can read prices directly. “Website” means one tap opens the official current search.'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: metricCard(t('Aktiv', 'Enabled'), '$enabled')),
          const SizedBox(width: 8),
          Expanded(child: metricCard(t('In-App Live', 'In-app live'), '$direct')),
        ]),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final source = entry.value;
          final status = source.canFetchInApp ? t('In-App Live bereit', 'In-app live ready') : t('Website-Suche', 'Website search');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    sourceBadge(source),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(source.name, style: const TextStyle(fontWeight: FontWeight.w900))),
                            if (source.recommended) ...[
                              const SizedBox(width: 6),
                              Chip(label: Text(t('Empfohlen', 'Recommended')), visualDensity: VisualDensity.compact),
                            ],
                          ]),
                          Text(source.subtitle, style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: source.canFetchInApp ? Colors.green.shade700 : Colors.blue.shade700)),
                        ],
                      ),
                    ),
                    Switch(
                      value: source.enabled,
                      onChanged: (v) {
                        setState(() => items[i] = source.copyWith(enabled: v));
                        save();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(onPressed: _addCustom, icon: const Icon(Icons.add_link), label: Text(t('Eigene Quelle hinzufügen', 'Add your own source'))),
        const SizedBox(height: 10),
        Text(
          t('Für Entwickler & Partner: Eine Quelle kann über ein kleines FlipRadar-Manifest hinzugefügt werden. So ist kein App-Update nötig.', 'For developers & partners: a source can be added with a small FlipRadar manifest, so no app update is required.'),
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class AddSourceSheet extends StatefulWidget {
  final bool english;
  const AddSourceSheet({super.key, required this.english});

  @override
  State<AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<AddSourceSheet> {
  final manifest = TextEditingController();
  final name = TextEditingController();
  final searchUrl = TextEditingController();
  final adapterUrl = TextEditingController();
  bool advanced = false;
  bool importing = false;
  String? error;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void dispose() {
    manifest.dispose();
    name.dispose();
    searchUrl.dispose();
    adapterUrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (manifest.text.trim().isEmpty) return;
    setState(() {
      importing = true;
      error = null;
    });
    try {
      final source = await SourceRegistry.importManifest(manifest.text.trim());
      if (!mounted) return;
      Navigator.pop(context, source);
    } catch (e) {
      setState(() => error = t('Import nicht möglich. Prüfe den Link und das Manifest.', 'Import failed. Check the link and manifest.'));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _manual() {
    try {
      final source = PriceSource.fromJson({
        'name': name.text.trim(),
        'subtitle': widget.english ? 'Custom source' : 'Eigene Quelle',
        'search_url': searchUrl.text.trim(),
        'adapter_url': adapterUrl.text.trim().isEmpty ? null : adapterUrl.text.trim(),
      });
      Navigator.pop(context, source);
    } catch (_) {
      setState(() => error = t('Name und Such-Link sind nötig. Im Such-Link muss {query} stehen.', 'Name and search link are required. The search link must contain {query}.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(t('Quelle hinzufügen', 'Add a source'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(t('Am einfachsten: einen FlipRadar-Manifest-Link einfügen. Für normale Nutzer reicht sonst Name + Such-Link.', 'Easiest: paste a FlipRadar manifest link. For regular users, name + search link is enough.'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextField(controller: manifest, decoration: InputDecoration(labelText: t('Manifest-Link (optional)', 'Manifest link (optional)'), hintText: 'https://example.com/flipradar-source.json')),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: importing ? null : _import, icon: const Icon(Icons.download), label: Text(importing ? t('Importiere…', 'Importing…') : t('Manifest importieren', 'Import manifest'))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
          TextField(controller: name, decoration: InputDecoration(labelText: t('Name der Website', 'Website name'), hintText: 'Mein Shop')),
          const SizedBox(height: 8),
          TextField(controller: searchUrl, decoration: InputDecoration(labelText: t('Such-Link', 'Search link'), hintText: 'https://shop.de/search?q={query}', helperText: t('{query} wird automatisch durch das Produkt ersetzt.', '{query} is automatically replaced by the product.'))),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Live-Adapter hinzufügen (für Entwickler)', 'Add live adapter (for developers)')),
            subtitle: Text(t('Nur nötig, wenn Preise direkt in FlipRadar erscheinen sollen.', 'Only needed if prices should appear directly inside FlipRadar.')),
            value: advanced,
            onChanged: (v) => setState(() => advanced = v),
          ),
          if (advanced)
            TextField(controller: adapterUrl, decoration: InputDecoration(labelText: t('Adapter-URL', 'Adapter URL'), hintText: 'https://api.example.com/search?q={query}')),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _manual, icon: const Icon(Icons.add), label: Text(t('Quelle speichern', 'Save source'))),
        ],
      ),
    );
  }
}

class FlipsPage extends StatelessWidget {
  final bool english;
  final List<FlipItem> flips;
  final ValueChanged<FlipItem> onUpdate;
  const FlipsPage({super.key, required this.english, required this.flips, required this.onUpdate});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final soldProfit = flips.where((e) => e.status == 'Sold').fold<double>(0, (a, b) => a + b.profit);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Meine Flips', 'My Flips'), t('Was gekauft wurde und was wirklich verdient wurde.', 'What you bought and what you actually earned.')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: metricCard(t('Gesamt', 'Total'), '${flips.length}')),
          const SizedBox(width: 8),
          Expanded(child: metricCard(t('Realisiert', 'Realized'), '${soldProfit.toStringAsFixed(0)} €')),
        ]),
        const SizedBox(height: 16),
        if (flips.isEmpty)
          infoBox(context, Icons.inventory_2_outlined, t('Noch keine Flips. Prüfe einen Deal und speichere ihn als Kauf.', 'No flips yet. Check a deal and save it as a purchase.')),
        ...flips.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w900))),
                        Chip(label: Text(f.status)),
                      ]),
                      Text('${f.buy.toStringAsFixed(0)} € → ${f.sell.toStringAsFixed(0)} € · ${t('Gewinn', 'Profit')} ${f.profit.toStringAsFixed(0)} € · ROI ${f.roi.toStringAsFixed(0)} %'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (f.status == 'Bought') OutlinedButton(onPressed: () => onUpdate(f.copyWith(status: 'Listed')), child: Text(t('Als inseriert markieren', 'Mark listed'))),
                          if (f.status != 'Sold') FilledButton.tonal(onPressed: () => onUpdate(f.copyWith(status: 'Sold')), child: Text(t('Als verkauft markieren', 'Mark sold'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class MorePage extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final UserPlan plan;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<String> onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlanPreview;

  const MorePage({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.plan,
    required this.onLanguage,
    required this.onBackend,
    required this.onRoi,
    required this.onPlanPreview,
  });

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  late final TextEditingController backend;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    backend = TextEditingController(text: widget.backend);
  }

  @override
  void dispose() {
    backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Mehr', 'More'), t('Einstellungen ohne Technik-Chaos.', 'Settings without tech chaos.')),
        const SizedBox(height: 14),
        PaywallCard(
          english: widget.english,
          plan: widget.plan,
          onOpen: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallPage(english: widget.english, current: widget.plan, onPreview: widget.onPlanPreview))),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(t('English', 'Deutsch')),
                subtitle: Text(t('App auf Englisch umstellen', 'Switch app to German')),
                value: widget.english,
                onChanged: widget.onLanguage,
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(t('Ziel-ROI', 'Target ROI')),
                subtitle: Slider(
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${widget.targetRoi.toStringAsFixed(0)} %',
                  value: widget.targetRoi.clamp(10, 100),
                  onChanged: widget.onRoi,
                ),
                trailing: Text('${widget.targetRoi.toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          collapsedBackgroundColor: Colors.white,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.settings_ethernet),
          title: Text(t('Live-Daten-Zentrale', 'Live data hub'), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(t('Nur nötig für direkte API-Preise', 'Only needed for direct API prices')),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Text(t('Für normale Nutzung musst du hier nichts einstellen. Wenn dein FlipRadar-Server läuft, genügt eine einzige Serveradresse – die einzelnen Portale werden dort verwaltet.', 'For normal use you do not need to set anything here. When your FlipRadar server is running, one server address is enough; individual portals are managed there.'), style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  TextField(controller: backend, decoration: const InputDecoration(labelText: 'FlipRadar API URL', hintText: 'https://api.deine-domain.de')),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => widget.onBackend(backend.text), child: Text(t('Server speichern', 'Save server')))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        infoBox(context, Icons.security_outlined, t('API-Schlüssel gehören auf den Server, nicht in die App. Das macht eBay, Amazon/Keepa und spätere Partnerquellen leichter austauschbar und sicherer.', 'API keys belong on the server, not in the app. This makes eBay, Amazon/Keepa and future partner sources easier to swap and safer.')),
      ],
    );
  }
}

class PaywallCard extends StatelessWidget {
  final bool english;
  final UserPlan plan;
  final VoidCallback onOpen;
  const PaywallCard({super.key, required this.english, required this.plan, required this.onOpen});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final isFree = plan == UserPlan.free;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isFree ? Icons.workspace_premium_outlined : Icons.workspace_premium),
              const SizedBox(width: 8),
              Expanded(child: Text(isFree ? 'FlipRadar FREE' : plan == UserPlan.pro ? 'FlipRadar PRO' : 'FlipRadar PRO+', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            ]),
            const SizedBox(height: 6),
            Text(isFree ? t('Kostenlos mit dezenten Werbeplätzen. Pro entfernt Werbung und schaltet Komfortfunktionen frei.', 'Free with subtle ad placements. Pro removes ads and unlocks convenience features.') : t('Pro-Vorschau ist aktiv. In dieser Test-APK wurde nichts berechnet.', 'Pro preview is active. No charge was made in this test APK.')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: onOpen, child: Text(t('Pläne ansehen', 'View plans')))),
          ],
        ),
      ),
    );
  }
}

class PaywallPage extends StatelessWidget {
  final bool english;
  final UserPlan current;
  final ValueChanged<UserPlan> onPreview;
  const PaywallPage({super.key, required this.english, required this.current, required this.onPreview});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('FlipRadar Pläne', 'FlipRadar plans'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(t('Monetarisierung, ohne die App nervig zu machen', 'Monetization without making the app annoying'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(t('In der Test-APK kannst du die Pläne nur ansehen und als Vorschau umschalten. Echte Käufe werden erst über Google Play/App Store aktiviert.', 'In this test APK you can only preview plans. Real purchases will be enabled through Google Play/App Store.'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          planCard(context, title: 'FREE', price: '0 €', bullets: [t('Preisvergleich & Websuchen', 'Price comparison & web searches'), t('Barcode-Scan', 'Barcode scan'), t('Flips lokal speichern', 'Save flips locally'), t('Dezente Werbung', 'Subtle ads')], selected: current == UserPlan.free, onTap: () => onPreview(UserPlan.free)),
          const SizedBox(height: 10),
          planCard(context, title: 'PRO', price: '9,99 € / Monat', bullets: [t('Keine Werbung', 'No ads'), t('Unbegrenzte Live-Checks', 'Unlimited live checks'), t('Watchlists & Preisalarme', 'Watchlists & price alerts'), t('Erweiterte Marktwerte', 'Advanced market values')], selected: current == UserPlan.pro, onTap: () => onPreview(UserPlan.pro), recommended: true),
          const SizedBox(height: 10),
          planCard(context, title: 'PRO+', price: '19,99 € / Monat', bullets: [t('Alles aus Pro', 'Everything in Pro'), t('Eigene/Partner-Quellen', 'Custom/partner sources'), t('Cross-Border & mehr Länder', 'Cross-border & more countries'), t('Export & Profi-Auswertung', 'Export & pro analytics')], selected: current == UserPlan.proPlus, onTap: () => onPreview(UserPlan.proPlus)),
          const SizedBox(height: 14),
          infoBox(context, Icons.ads_click_outlined, t('Werbestrategie: Banner/native Werbeplätze an ruhigen Stellen. Keine zufälligen Vollbildanzeigen mitten beim Prüfen eines Deals.', 'Ad strategy: banner/native placements in calm areas. No random full-screen ads while checking a deal.')),
          const SizedBox(height: 10),
          Text(t('Hinweis: „Vorschau aktivieren“ ist nur zum Testen des Designs und löst keine Zahlung aus.', 'Note: “Enable preview” is only for testing the design and does not trigger a payment.'), style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

Widget planCard(BuildContext context, {required String title, required String price, required List<String> bullets, required bool selected, required VoidCallback onTap, bool recommended = false}) {
  return Card(
    color: recommended ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45) : null,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            if (recommended) ...[const SizedBox(width: 8), const Chip(label: Text('BEST VALUE'))],
            const Spacer(),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          ...bullets.map((b) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [const Icon(Icons.check, size: 18), const SizedBox(width: 7), Expanded(child: Text(b))]))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: selected ? FilledButton(onPressed: null, child: const Text('AKTIV / ACTIVE')) : OutlinedButton(onPressed: onTap, child: const Text('VORSCHAU AKTIVIEREN / ENABLE PREVIEW'))),
        ],
      ),
    ),
  );
}

class SponsoredSlot extends StatelessWidget {
  final bool english;
  const SponsoredSlot({super.key, required this.english});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(english ? 'Ad space' : 'Werbeplatz', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(english ? 'Reserved for a subtle banner/native ad in the Free plan.' : 'Reserviert für eine dezente Banner-/Native-Anzeige im Free-Tarif.', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ])),
          const Text('AD', style: TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  final bool english;
  const ScannerPage({super.key, required this.english});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false;
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Barcode scannen', 'Scan barcode'))),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (done) return;
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value == null || value.isEmpty) return;
              done = true;
              Navigator.pop(context, value);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: Colors.black87,
              child: Text(t('Barcode in die Mitte halten. FlipRadar übernimmt den Code automatisch.', 'Hold the barcode in the center. FlipRadar captures it automatically.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget header(String title, String subtitle) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );

Widget darkStat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        ],
      ),
    );

Widget metricCard(String label, String value) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
        ]),
      ),
    );

Widget resultBox(String label, String value) => Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );

Widget infoBox(BuildContext context, IconData icon, String text) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );

Widget sourceBadge(PriceSource source) {
  Color c;
  try {
    c = Color(int.parse('FF${source.colorHex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    c = const Color(0xFF5746E8);
  }
  return CircleAvatar(backgroundColor: c.withValues(alpha: 0.13), child: Text(source.name.substring(0, 1).toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w900)));
}

Widget decisionBanner(BuildContext context, bool buy, String Function(String, String) t) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: buy ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: buy ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Row(children: [
        Icon(buy ? Icons.thumb_up_alt : Icons.pan_tool_alt, color: buy ? Colors.green.shade800 : Colors.orange.shade800),
        const SizedBox(width: 10),
        Expanded(child: Text(buy ? t('PREIS PASST – liegt innerhalb deines BUY MAX.', 'PRICE FITS – it is within your BUY MAX.') : t('EHER LASSEN – Preis liegt über deinem BUY MAX.', 'BETTER SKIP – price is above your BUY MAX.'), style: const TextStyle(fontWeight: FontWeight.w900))),
      ]),
    );
