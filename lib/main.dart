import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const FlipRadarApp());

const String kApiBase = String.fromEnvironment('FLIPRADAR_API_URL', defaultValue: '');

class FlipRadarApp extends StatefulWidget {
  const FlipRadarApp({super.key});

  @override
  State<FlipRadarApp> createState() => _FlipRadarAppState();
}

class _FlipRadarAppState extends State<FlipRadarApp> {
  bool english = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3559E0),
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
      ),
      home: MainShell(
        english: english,
        onLanguageChanged: (value) => setState(() => english = value),
      ),
    );
  }
}

class FlipItem {
  final String id;
  final String name;
  final double buy;
  final double sell;
  final double fees;
  final double shipping;
  final double other;
  final String status;
  final String source;
  final DateTime createdAt;

  const FlipItem({
    required this.id,
    required this.name,
    required this.buy,
    required this.sell,
    required this.fees,
    required this.shipping,
    required this.other,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  double get costs => fees + shipping + other;
  double get profit => sell - buy - costs;
  double get roi => buy <= 0 ? 0 : profit / buy * 100;

  FlipItem copyWith({String? status, double? sell}) => FlipItem(
        id: id,
        name: name,
        buy: buy,
        sell: sell ?? this.sell,
        fees: fees,
        shipping: shipping,
        other: other,
        status: status ?? this.status,
        source: source,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buy': buy,
        'sell': sell,
        'fees': fees,
        'shipping': shipping,
        'other': other,
        'status': status,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FlipItem.fromJson(Map<String, dynamic> json) => FlipItem(
        id: json['id'] as String,
        name: json['name'] as String,
        buy: (json['buy'] as num).toDouble(),
        sell: (json['sell'] as num).toDouble(),
        fees: (json['fees'] as num).toDouble(),
        shipping: (json['shipping'] as num).toDouble(),
        other: (json['other'] as num).toDouble(),
        status: json['status'] as String,
        source: json['source'] as String? ?? 'Manual',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class WatchItem {
  final String query;
  final double maxPrice;
  final String source;

  const WatchItem({required this.query, required this.maxPrice, required this.source});

  Map<String, dynamic> toJson() => {'query': query, 'maxPrice': maxPrice, 'source': source};
  factory WatchItem.fromJson(Map<String, dynamic> json) => WatchItem(
        query: json['query'] as String,
        maxPrice: (json['maxPrice'] as num).toDouble(),
        source: json['source'] as String,
      );
}

class MarketSnapshot {
  final double median;
  final double low;
  final double high;
  final int soldCount;
  final int activeCount;
  final double confidence;

  const MarketSnapshot({
    required this.median,
    required this.low,
    required this.high,
    required this.soldCount,
    required this.activeCount,
    required this.confidence,
  });

  double get sellThrough => activeCount <= 0 ? 100 : (soldCount / activeCount * 100).clamp(0, 999).toDouble();
}

class MarketListing {
  final String source;
  final String title;
  final double price;
  final double shipping;
  final String condition;
  final String url;
  final bool live;

  const MarketListing({
    required this.source,
    required this.title,
    required this.price,
    required this.shipping,
    required this.condition,
    required this.url,
    required this.live,
  });

  double get total => price + shipping;

  factory MarketListing.fromJson(Map<String, dynamic> json) => MarketListing(
        source: json['source'] as String? ?? 'eBay DE',
        title: json['title'] as String? ?? 'Listing',
        price: (json['price'] as num? ?? 0).toDouble(),
        shipping: (json['shipping'] as num? ?? 0).toDouble(),
        condition: json['condition'] as String? ?? 'Used',
        url: json['url'] as String? ?? '',
        live: true,
      );
}

class AppStore {
  static const _flipsKey = 'flips_v03';
  static const _watchKey = 'watch_v03';
  static const _roiKey = 'target_roi_v03';

  static Future<List<FlipItem>> loadFlips() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_flipsKey);
    if (raw == null) return _seedFlips();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => FlipItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _seedFlips();
    }
  }

  static Future<void> saveFlips(List<FlipItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_flipsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<List<WatchItem>> loadWatchlist() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_watchKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => WatchItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWatchlist(List<WatchItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_watchKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<double> loadTargetRoi() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_roiKey) ?? 30;
  }

  static Future<void> saveTargetRoi(double value) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_roiKey, value);
  }

  static List<FlipItem> _seedFlips() => [
        FlipItem(
          id: 'seed-1',
          name: 'PlayStation 5 Slim',
          buy: 250,
          sell: 379,
          fees: 38,
          shipping: 14,
          other: 5,
          status: 'Sold',
          source: 'Kleinanzeigen',
          createdAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
        FlipItem(
          id: 'seed-2',
          name: 'MacBook Air M2',
          buy: 400,
          sell: 599,
          fees: 60,
          shipping: 9,
          other: 0,
          status: 'Listed',
          source: 'eBay DE',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];
}

class MarketService {
  static Future<List<MarketListing>> search(String query, String source) async {
    if (kApiBase.isNotEmpty && (source == 'All' || source == 'eBay DE')) {
      try {
        final uri = Uri.parse('$kApiBase/v1/market/search').replace(queryParameters: {'q': query, 'source': 'ebay_de'});
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>? ?? []).map((e) => MarketListing.fromJson(e as Map<String, dynamic>)).toList();
          if (items.isNotEmpty) return items;
        }
      } catch (_) {}
    }
    return _demoListings(query, source);
  }

  static MarketSnapshot snapshot(String query) {
    final seed = query.toLowerCase().codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff);
    final r = math.Random(seed);
    final base = 80 + r.nextInt(620).toDouble();
    final median = (base / 5).round() * 5.0;
    final spread = 0.12 + r.nextDouble() * 0.14;
    final sold = 8 + r.nextInt(55);
    final active = 10 + r.nextInt(70);
    final confidence = (0.55 + math.min(0.4, sold / 150).toDouble()).clamp(0.55, 0.95).toDouble();
    return MarketSnapshot(
      median: median,
      low: (median * (1 - spread)).roundToDouble(),
      high: (median * (1 + spread)).roundToDouble(),
      soldCount: sold,
      activeCount: active,
      confidence: confidence,
    );
  }

  static List<MarketListing> _demoListings(String query, String source) {
    final snap = snapshot(query);
    final sources = source == 'All' ? ['eBay DE', 'Kleinanzeigen'] : [source];
    final list = <MarketListing>[];
    for (var i = 0; i < 6; i++) {
      final s = sources[i % sources.length];
      final factor = 0.70 + (i * 0.08);
      final p = (snap.median * factor / 5).round() * 5.0;
      list.add(MarketListing(
        source: s,
        title: '$query ${i == 0 ? 'Top Deal' : i == 1 ? 'sehr guter Zustand' : 'Angebot ${i + 1}'}',
        price: p,
        shipping: s == 'eBay DE' ? (i.isEven ? 0 : 6.99) : 0,
        condition: i == 0 ? 'Used - Good' : 'Used',
        url: portalSearchUrl(s, query),
        live: false,
      ));
    }
    return list;
  }

  static String portalSearchUrl(String source, String query) {
    final q = Uri.encodeQueryComponent(query);
    if (source == 'Kleinanzeigen') return 'https://www.kleinanzeigen.de/s-suchanfrage.html?keywords=$q';
    return 'https://www.ebay.de/sch/i.html?_nkw=$q';
  }
}

class MainShell extends StatefulWidget {
  final bool english;
  final ValueChanged<bool> onLanguageChanged;

  const MainShell({super.key, required this.english, required this.onLanguageChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool loading = true;
  List<FlipItem> flips = [];
  List<WatchItem> watchlist = [];
  double targetRoi = 30;
  String pendingAnalyzeQuery = '';

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedFlips = await AppStore.loadFlips();
    final loadedWatch = await AppStore.loadWatchlist();
    final roi = await AppStore.loadTargetRoi();
    if (!mounted) return;
    setState(() {
      flips = loadedFlips;
      watchlist = loadedWatch;
      targetRoi = roi;
      loading = false;
    });
  }

  Future<void> _saveFlips() => AppStore.saveFlips(flips);
  Future<void> _saveWatch() => AppStore.saveWatchlist(watchlist);

  void _analyze(String query) {
    setState(() {
      pendingAnalyzeQuery = query;
      index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pages = <Widget>[
      HomePage(
        english: widget.english,
        flips: flips,
        watchCount: watchlist.length,
        onAnalyze: () => _analyze(''),
        onMarket: () => setState(() => index = 2),
        onBarcode: () async {
          final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => BarcodeScannerPage(english: widget.english)));
          if (code != null && code.isNotEmpty) _analyze(code);
        },
      ),
      AnalyzePage(
        key: ValueKey('$pendingAnalyzeQuery-${flips.length}'),
        english: widget.english,
        initialQuery: pendingAnalyzeQuery,
        targetRoi: targetRoi,
        onSaved: (item) {
          setState(() {
            flips.insert(0, item);
            pendingAnalyzeQuery = '';
            index = 3;
          });
          _saveFlips();
        },
      ),
      MarketPage(
        english: widget.english,
        watchlist: watchlist,
        onAnalyze: _analyze,
        onWatch: (item) {
          setState(() => watchlist.add(item));
          _saveWatch();
        },
        onUnwatch: (item) {
          setState(() => watchlist.removeWhere((w) => w.query == item.query && w.source == item.source));
          _saveWatch();
        },
      ),
      FlipsPage(
        english: widget.english,
        flips: flips,
        onUpdate: (updated) {
          setState(() {
            final i = flips.indexWhere((f) => f.id == updated.id);
            if (i >= 0) flips[i] = updated;
          });
          _saveFlips();
        },
      ),
      ProfilePage(
        english: widget.english,
        onLanguageChanged: widget.onLanguageChanged,
        targetRoi: targetRoi,
        onTargetRoiChanged: (value) {
          setState(() => targetRoi = value);
          AppStore.saveTargetRoi(value);
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('Start', 'Home')),
          NavigationDestination(icon: const Icon(Icons.calculate_outlined), selectedIcon: const Icon(Icons.calculate), label: t('Analyse', 'Analyze')),
          NavigationDestination(icon: const Icon(Icons.radar_outlined), selectedIcon: const Icon(Icons.radar), label: t('Markt', 'Market')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Flips', 'Flips')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t('Profil', 'Profile')),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class HomePage extends StatelessWidget {
  final bool english;
  final List<FlipItem> flips;
  final int watchCount;
  final VoidCallback onAnalyze;
  final VoidCallback onMarket;
  final VoidCallback onBarcode;

  const HomePage({
    super.key,
    required this.english,
    required this.flips,
    required this.watchCount,
    required this.onAnalyze,
    required this.onMarket,
    required this.onBarcode,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final invested = flips.where((f) => f.status != 'Sold').fold<double>(0, (a, b) => a + b.buy);
    final realized = flips.where((f) => f.status == 'Sold').fold<double>(0, (a, b) => a + b.profit);
    final avgRoi = flips.isEmpty ? 0 : flips.fold<double>(0, (a, b) => a + b.roi) / flips.length;

    return ListView(padding: const EdgeInsets.all(18), children: [
      PageHeader(
        title: 'FlipRadar',
        subtitle: t('Schneller entscheiden. Besser einkaufen. Mehr Marge.', 'Decide faster. Buy smarter. Keep more margin.'),
        trailing: const CircleAvatar(child: Icon(Icons.bolt)),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF172554), Color(0xFF3559E0)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Reselling Cockpit', 'Reselling cockpit'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text('${realized.toStringAsFixed(0)} €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
          Text(t('realisierter Gewinn', 'realized profit'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _DarkStat(label: t('Gebunden', 'Invested'), value: '${invested.toStringAsFixed(0)} €')),
            Expanded(child: _DarkStat(label: 'Ø ROI', value: '${avgRoi.toStringAsFixed(0)} %')),
            Expanded(child: _DarkStat(label: t('Watchlist', 'Watchlist'), value: '$watchCount')),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text(t('Schnellstart', 'Quick start'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _QuickAction(icon: Icons.qr_code_scanner, title: t('Barcode', 'Barcode'), subtitle: t('EAN/UPC scannen', 'Scan EAN/UPC'), onTap: onBarcode)),
        const SizedBox(width: 10),
        Expanded(child: _QuickAction(icon: Icons.calculate, title: t('Deal prüfen', 'Check deal'), subtitle: t('Gewinn + ROI', 'Profit + ROI'), onTap: onAnalyze)),
      ]),
      const SizedBox(height: 10),
      _QuickAction(icon: Icons.radar, title: t('Markt scannen', 'Scan market'), subtitle: t('eBay DE + Kleinanzeigen vergleichen', 'Compare eBay DE + Kleinanzeigen'), onTap: onMarket),
      const SizedBox(height: 22),
      _TipCard(
        icon: Icons.lightbulb_outline,
        title: t('Sourcing-Modus', 'Sourcing mode'),
        body: t(
          'Nutze Median, Sell-through, Preisrange und Buy-Max zusammen. Ein hoher Angebotspreis allein ist noch kein Marktwert.',
          'Use median, sell-through, price range and Buy-Max together. A high asking price alone is not market value.',
        ),
      ),
      const SizedBox(height: 22),
      Text(t('Aktive Flips', 'Active flips'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...flips.where((f) => f.status != 'Sold').take(3).map((f) => _FlipMiniCard(item: f)),
    ]);
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _DarkStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _TipCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.35)),
          ])),
        ]),
      );
}

class _FlipMiniCard extends StatelessWidget {
  final FlipItem item;
  const _FlipMiniCard({required this.item});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(child: Text('${item.roi.round()}%')),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${item.source} • ${item.status}'),
          trailing: Text('${item.profit >= 0 ? '+' : ''}${item.profit.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}

class AnalyzePage extends StatefulWidget {
  final bool english;
  final String initialQuery;
  final double targetRoi;
  final ValueChanged<FlipItem> onSaved;

  const AnalyzePage({super.key, required this.english, required this.initialQuery, required this.targetRoi, required this.onSaved});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  late final TextEditingController product;
  final buy = TextEditingController(text: '200');
  final sell = TextEditingController();
  final feePercent = TextEditingController(text: '11');
  final shipping = TextEditingController(text: '7');
  final other = TextEditingController(text: '0');
  String source = 'eBay DE';
  bool analyzed = false;
  late MarketSnapshot market;
  double profit = 0;
  double roi = 0;
  double maxBuy = 0;
  int score = 0;

  String t(String de, String en) => widget.english ? en : de;
  double n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    product = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _useMarket());
  }

  void _useMarket() {
    final q = product.text.trim().isEmpty ? 'iPhone 15 Pro 256 GB' : product.text.trim();
    market = MarketService.snapshot(q);
    sell.text = market.median.toStringAsFixed(0);
    _calculate();
  }

  void _calculate() {
    final q = product.text.trim().isEmpty ? 'Produkt' : product.text.trim();
    market = MarketService.snapshot(q);
    final b = n(buy);
    final s = n(sell) <= 0 ? market.median : n(sell);
    final fees = s * n(feePercent) / 100;
    final fixed = n(shipping) + n(other);
    final p = s - fees - fixed - b;
    final r = b <= 0 ? 0.0 : p / b * 100;
    final netAfterSaleCosts = s - fees - fixed;
    final max = netAfterSaleCosts / (1 + widget.targetRoi / 100);
    final marginComponent = (r / 60 * 45).clamp(0, 45).toDouble();
    final demandComponent = (market.sellThrough / 100 * 25).clamp(0, 25).toDouble();
    final confidenceComponent = market.confidence * 20;
    final spreadPenalty = ((market.high - market.low) / math.max(1, market.median) * 20).clamp(0, 10).toDouble();
    final raw = 10 + marginComponent + demandComponent + confidenceComponent - spreadPenalty;
    setState(() {
      sell.text = s.toStringAsFixed(0);
      profit = p;
      roi = r;
      maxBuy = max;
      score = raw.round().clamp(0, 100).toInt();
      analyzed = true;
    });
  }

  @override
  void dispose() {
    product.dispose();
    buy.dispose();
    sell.dispose();
    feePercent.dispose();
    shipping.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      PageHeader(title: t('Deal-Check', 'Deal check'), subtitle: t('Marktwert + Kosten + Risiko in einer Entscheidung.', 'Market value + costs + risk in one decision.')),
      const SizedBox(height: 16),
      TextField(controller: product, decoration: InputDecoration(labelText: t('Produkt / EAN / Suchbegriff', 'Product / EAN / search term'), prefixIcon: const Icon(Icons.search))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _numField(buy, t('Einkauf €', 'Buy €'))),
        const SizedBox(width: 10),
        Expanded(child: _numField(sell, t('Verkauf €', 'Sell €'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _numField(feePercent, t('Gebühr %', 'Fee %'))),
        const SizedBox(width: 10),
        Expanded(child: _numField(shipping, t('Versand €', 'Shipping €'))),
        const SizedBox(width: 10),
        Expanded(child: _numField(other, t('Sonst. €', 'Other €'))),
      ]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: source,
        decoration: InputDecoration(labelText: t('Verkaufsportal', 'Selling portal')),
        items: const ['eBay DE', 'Kleinanzeigen', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() {
          source = v ?? 'eBay DE';
          if (source == 'Kleinanzeigen') feePercent.text = '0';
        }),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _useMarket, icon: const Icon(Icons.auto_graph), label: Text(t('Median übernehmen', 'Use median')))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.bolt), label: Text(t('Prüfen', 'Check')))),
      ]),
      if (analyzed) ...[
        const SizedBox(height: 18),
        _DecisionCard(english: widget.english, score: score, profit: profit, roi: roi, maxBuy: maxBuy, targetRoi: widget.targetRoi),
        const SizedBox(height: 12),
        _MarketSnapshotCard(english: widget.english, market: market),
        const SizedBox(height: 12),
        _ScenarioCard(english: widget.english, buy: n(buy), feePercent: n(feePercent), shipping: n(shipping), other: n(other), market: market),
        const SizedBox(height: 12),
        _RiskCard(english: widget.english, query: product.text),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            final sale = n(sell);
            widget.onSaved(FlipItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: product.text.trim().isEmpty ? 'Unnamed item' : product.text.trim(),
              buy: n(buy),
              sell: sale,
              fees: sale * n(feePercent) / 100,
              shipping: n(shipping),
              other: n(other),
              status: 'Bought',
              source: source,
              createdAt: DateTime.now(),
            ));
          },
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(t('Als Flip speichern', 'Save as flip')),
        ),
      ],
    ]);
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );
}

class _DecisionCard extends StatelessWidget {
  final bool english;
  final int score;
  final double profit;
  final double roi;
  final double maxBuy;
  final double targetRoi;

  const _DecisionCard({required this.english, required this.score, required this.profit, required this.roi, required this.maxBuy, required this.targetRoi});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final label = score >= 80 ? t('KAUFEN', 'BUY') : score >= 65 ? t('PRÜFEN', 'CHECK') : t('EHER NICHT', 'SKIP');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 28, child: Text('$score', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(t('Flip Score – Markt, Marge & Nachfrage', 'Flip Score – market, margin & demand'), style: const TextStyle(color: Colors.black54)),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Metric(label: t('Gewinn', 'Profit'), value: '${profit.toStringAsFixed(0)} €')),
            Expanded(child: _Metric(label: 'ROI', value: '${roi.toStringAsFixed(0)} %')),
            Expanded(child: _Metric(label: 'BUY MAX', value: '${maxBuy.toStringAsFixed(0)} €')),
          ]),
          const SizedBox(height: 10),
          Text(t('Buy-Max basiert auf deinem Ziel-ROI von ${targetRoi.toStringAsFixed(0)} %.', 'Buy-Max is based on your target ROI of ${targetRoi.toStringAsFixed(0)}%.'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ]);
}

class _MarketSnapshotCard extends StatelessWidget {
  final bool english;
  final MarketSnapshot market;
  const _MarketSnapshotCard({required this.english, required this.market});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Markt-Snapshot', 'Market snapshot'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Metric(label: t('Median', 'Median'), value: '${market.median.toStringAsFixed(0)} €')),
              Expanded(child: _Metric(label: t('Range', 'Range'), value: '${market.low.toStringAsFixed(0)}–${market.high.toStringAsFixed(0)}')),
              Expanded(child: _Metric(label: 'Sell-through', value: '${market.sellThrough.toStringAsFixed(0)} %')),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: market.confidence),
            const SizedBox(height: 6),
            Text(t('Confidence ${(market.confidence * 100).round()} % • ${market.soldCount} Verkäufe / ${market.activeCount} aktive Angebote', 'Confidence ${(market.confidence * 100).round()}% • ${market.soldCount} sold / ${market.activeCount} active listings'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
      );
}

class _ScenarioCard extends StatelessWidget {
  final bool english;
  final double buy;
  final double feePercent;
  final double shipping;
  final double other;
  final MarketSnapshot market;
  const _ScenarioCard({required this.english, required this.buy, required this.feePercent, required this.shipping, required this.other, required this.market});
  String t(String de, String en) => english ? en : de;
  double p(double sale) => sale - sale * feePercent / 100 - shipping - other - buy;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('3 Szenarien', '3 scenarios'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            _scenario(t('Konservativ', 'Conservative'), market.low, p(market.low)),
            _scenario(t('Realistisch', 'Realistic'), market.median, p(market.median)),
            _scenario(t('Optimistisch', 'Optimistic'), market.high, p(market.high)),
          ]),
        ),
      );

  Widget _scenario(String name, double sale, double profit) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Expanded(child: Text(name)),
          Text('${sale.toStringAsFixed(0)} €', style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 14),
          SizedBox(width: 72, child: Text('${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)} €', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}

class _RiskCard extends StatelessWidget {
  final bool english;
  final String query;
  const _RiskCard({required this.english, required this.query});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    List<String> risks;
    if (q.contains('iphone') || q.contains('phone') || q.contains('samsung')) {
      risks = [t('IMEI / Aktivierungssperre prüfen', 'Check IMEI / activation lock'), t('Akku-Zustand dokumentieren', 'Document battery health'), t('Rechnung & Wasserschaden prüfen', 'Check receipt & water damage')];
    } else if (q.contains('macbook') || q.contains('laptop') || q.contains('notebook')) {
      risks = [t('MDM/iCloud/BIOS-Sperren prüfen', 'Check MDM/iCloud/BIOS locks'), t('Akkuzyklen testen', 'Check battery cycles'), t('Display, Tastatur, Ports testen', 'Test display, keyboard, ports')];
    } else if (q.contains('nike') || q.contains('jordan') || q.contains('sneaker')) {
      risks = [t('Authentizität prüfen', 'Check authenticity'), t('Größe/Zustand exakt dokumentieren', 'Document size/condition precisely'), t('Box/Beleg erhöhen Wiederverkaufswert', 'Box/receipt can improve resale value')];
    } else {
      risks = [t('Seriennummer / Eigentumsnachweis', 'Serial number / proof of ownership'), t('Funktion vor Kauf testen', 'Test functionality before buying'), t('Zustand mit Fotos dokumentieren', 'Document condition with photos')];
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Risiko-Check vor Kauf', 'Pre-buy risk check'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          ...risks.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.check_circle_outline, size: 19), const SizedBox(width: 8), Expanded(child: Text(r))]))),
        ]),
      ),
    );
  }
}

class MarketPage extends StatefulWidget {
  final bool english;
  final List<WatchItem> watchlist;
  final ValueChanged<String> onAnalyze;
  final ValueChanged<WatchItem> onWatch;
  final ValueChanged<WatchItem> onUnwatch;

  const MarketPage({super.key, required this.english, required this.watchlist, required this.onAnalyze, required this.onWatch, required this.onUnwatch});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final query = TextEditingController(text: 'iPhone 15 Pro 256 GB');
  String source = 'All';
  bool loading = false;
  List<MarketListing> results = [];
  MarketSnapshot? snap;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    setState(() => loading = true);
    final items = await MarketService.search(q, source);
    if (!mounted) return;
    setState(() {
      results = items;
      snap = MarketService.snapshot(q);
      loading = false;
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isWatched(String q) => widget.watchlist.any((w) => w.query.toLowerCase() == q.toLowerCase() && (w.source == source || source == 'All'));

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSnap = snap;
    return ListView(padding: const EdgeInsets.all(18), children: [
      PageHeader(title: t('Markt-Scanner', 'Market scanner'), subtitle: t('Live-Portale öffnen + API-ready Preisvergleich.', 'Open live portals + API-ready price comparison.')),
      const SizedBox(height: 14),
      TextField(
        controller: query,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: t('Produkt, Modell oder EAN', 'Product, model or EAN'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: ['All', 'eBay DE', 'Kleinanzeigen'].map((s) => ChoiceChip(label: Text(s == 'All' ? t('Alle', 'All') : s), selected: source == s, onSelected: (_) { setState(() => source = s); _search(); })).toList()),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton.tonalIcon(onPressed: () => _open(MarketService.portalSearchUrl('eBay DE', query.text)), icon: const Icon(Icons.open_in_new), label: const Text('eBay DE'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.tonalIcon(onPressed: () => _open(MarketService.portalSearchUrl('Kleinanzeigen', query.text)), icon: const Icon(Icons.open_in_new), label: const Text('Kleinanzeigen'))),
      ]),
      const SizedBox(height: 12),
      if (currentSnap != null) _MarketSnapshotCard(english: widget.english, market: currentSnap),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => widget.onAnalyze(query.text.trim()), icon: const Icon(Icons.calculate), label: Text(t('Deal prüfen', 'Check deal')))),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: t('Watchlist', 'Watchlist'),
          onPressed: () {
            final q = query.text.trim();
            if (q.isEmpty) return;
            final w = WatchItem(query: q, maxPrice: currentSnap?.low ?? 0, source: source == 'All' ? 'eBay DE' : source);
            if (_isWatched(q)) {
              widget.onUnwatch(w);
            } else {
              widget.onWatch(w);
            }
            setState(() {});
          },
          icon: Icon(_isWatched(query.text.trim()) ? Icons.notifications_active : Icons.add_alert),
        ),
      ]),
      const SizedBox(height: 18),
      if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      if (!loading) ...results.map((item) => _MarketListingCard(english: widget.english, item: item, median: currentSnap?.median ?? 0, onOpen: () => _open(item.url))),
      const SizedBox(height: 8),
      _TipCard(
        icon: kApiBase.isEmpty ? Icons.info_outline : Icons.cloud_done_outlined,
        title: kApiBase.isEmpty ? t('Demo-Daten + echte Portal-Links', 'Demo data + real portal links') : t('Backend verbunden', 'Backend connected'),
        body: kApiBase.isEmpty
            ? t('Die Karten sind aktuell Schätz-/Testdaten. eBay-Live-Daten werden automatisch aktiv, sobald der FlipRadar-Backend-Endpunkt mit eBay-Zugang hinterlegt ist. Portal-Buttons öffnen bereits echte Suchergebnisse.', 'Cards currently use estimate/test data. eBay live data activates automatically once the FlipRadar backend with eBay access is configured. Portal buttons already open real search results.')
            : t('eBay-Daten werden über den FlipRadar-Backend-Adapter geladen.', 'eBay data is loaded through the FlipRadar backend adapter.'),
      ),
      if (widget.watchlist.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(t('Watchlist', 'Watchlist'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...widget.watchlist.map((w) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const Icon(Icons.notifications_active_outlined), title: Text(w.query), subtitle: Text('${w.source} • ≤ ${w.maxPrice.toStringAsFixed(0)} €')))),
      ],
    ]);
  }
}

class _MarketListingCard extends StatelessWidget {
  final bool english;
  final MarketListing item;
  final double median;
  final VoidCallback onOpen;
  const _MarketListingCard({required this.english, required this.item, required this.median, required this.onOpen});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final discount = median <= 0 ? 0.0 : (median - item.total) / median * 100;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(child: Text(item.source == 'eBay DE' ? 'eB' : 'KA', style: const TextStyle(fontWeight: FontWeight.bold))),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${item.source} • ${item.condition}${item.live ? ' • LIVE' : ' • DEMO'}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${item.total.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(discount > 0 ? '${discount.toStringAsFixed(0)}% ${t('unter Median', 'below median')}' : t('am Markt', 'market'), style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
        onTap: onOpen,
      ),
    );
  }
}

class BarcodeScannerPage extends StatelessWidget {
  final bool english;
  const BarcodeScannerPage({super.key, required this.english});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Barcode scannen', 'Scan barcode'))),
        body: Stack(children: [
          MobileScanner(onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && code.isNotEmpty) Navigator.pop(context, code);
          }),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              child: Text(t('EAN/UPC in den Rahmen halten. Der Code wird direkt in den Deal-Check übernommen.', 'Hold EAN/UPC inside the frame. The code is sent directly to Deal Check.'), style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
          )
        ]),
      );
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class FlipsPage extends StatefulWidget {
  final bool english;
  final List<FlipItem> flips;
  final ValueChanged<FlipItem> onUpdate;
  const FlipsPage({super.key, required this.english, required this.flips, required this.onUpdate});

  @override
  State<FlipsPage> createState() => _FlipsPageState();
}

class _FlipsPageState extends State<FlipsPage> {
  String filter = 'All';
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    final items = filter == 'All' ? widget.flips : widget.flips.where((f) => f.status == filter).toList();
    final realized = widget.flips.where((f) => f.status == 'Sold').fold<double>(0, (a, b) => a + b.profit);
    final stock = widget.flips.where((f) => f.status != 'Sold').fold<double>(0, (a, b) => a + b.buy);
    return ListView(padding: const EdgeInsets.all(18), children: [
      PageHeader(title: t('Meine Flips', 'My flips'), subtitle: t('Vom Einkauf bis zum Verkauf – mobil dokumentiert.', 'From purchase to sale – tracked on mobile.')),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _SummaryTile(label: t('Gewinn', 'Profit'), value: '${realized.toStringAsFixed(0)} €')),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: t('Lagerwert', 'Inventory cost'), value: '${stock.toStringAsFixed(0)} €')),
      ]),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['All', 'Bought', 'Listed', 'Sold'].map((s) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(_statusLabel(s)), selected: filter == s, onSelected: (_) => setState(() => filter = s)))).toList())),
      const SizedBox(height: 12),
      if (items.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(t('Noch keine Flips in diesem Status.', 'No flips in this status yet.')))),
      ...items.map((f) => _FlipCard(english: widget.english, item: f, onUpdate: widget.onUpdate)),
    ]);
  }

  String _statusLabel(String s) {
    if (!widget.english) return {'All': 'Alle', 'Bought': 'Gekauft', 'Listed': 'Inseriert', 'Sold': 'Verkauft'}[s] ?? s;
    return s;
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22))])));
}

class _FlipCard extends StatelessWidget {
  final bool english;
  final FlipItem item;
  final ValueChanged<FlipItem> onUpdate;
  const _FlipCard({required this.english, required this.item, required this.onUpdate});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(item.createdAt).inDays;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text('${item.roi.round()}%')),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${item.source} • ${_status(item.status)} • $age ${t('Tage', 'days')}'),
        trailing: Text('${item.profit >= 0 ? '+' : ''}${item.profit.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Row(children: [
            Expanded(child: _Metric(label: t('Einkauf', 'Buy'), value: '${item.buy.toStringAsFixed(0)} €')),
            Expanded(child: _Metric(label: t('Verkauf', 'Sell'), value: '${item.sell.toStringAsFixed(0)} €')),
            Expanded(child: _Metric(label: t('Kosten', 'Costs'), value: '${item.costs.toStringAsFixed(0)} €')),
          ]),
          const SizedBox(height: 12),
          if (item.status == 'Bought') SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => onUpdate(item.copyWith(status: 'Listed')), child: Text(t('Als inseriert markieren', 'Mark as listed')))),
          if (item.status != 'Sold') SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => onUpdate(item.copyWith(status: 'Sold')), child: Text(t('Als verkauft markieren', 'Mark as sold')))),
        ],
      ),
    );
  }

  String _status(String s) => english ? s : {'Bought': 'Gekauft', 'Listed': 'Inseriert', 'Sold': 'Verkauft'}[s] ?? s;
}

class ProfilePage extends StatelessWidget {
  final bool english;
  final ValueChanged<bool> onLanguageChanged;
  final double targetRoi;
  final ValueChanged<double> onTargetRoiChanged;

  const ProfilePage({super.key, required this.english, required this.onLanguageChanged, required this.targetRoi, required this.onTargetRoiChanged});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
        PageHeader(title: t('Profil & Einstellungen', 'Profile & settings'), subtitle: t('Passe FlipRadar an deine Strategie an.', 'Tune FlipRadar to your strategy.')),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          SwitchListTile(title: Text(t('Englisch', 'English')), subtitle: Text(t('App-Sprache auf Englisch umstellen', 'Use English interface')), value: english, onChanged: onLanguageChanged),
          const Divider(height: 1),
          ListTile(title: Text(t('Ziel-ROI', 'Target ROI')), subtitle: Slider(value: targetRoi, min: 10, max: 100, divisions: 18, label: '${targetRoi.round()} %', onChanged: onTargetRoiChanged), trailing: Text('${targetRoi.round()} %', style: const TextStyle(fontWeight: FontWeight.w900))),
        ])),
        const SizedBox(height: 16),
        Text(t('Datenquellen', 'Data sources'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _SourceTile(name: 'eBay DE', status: kApiBase.isEmpty ? t('API-ready • Backend noch nicht verbunden', 'API-ready • backend not connected') : t('API verbunden', 'API connected'), icon: Icons.shopping_bag_outlined),
        const SizedBox(height: 8),
        _SourceTile(name: 'Kleinanzeigen', status: t('Live-Portal-Link • kein unerlaubtes Scraping', 'Live portal link • no prohibited scraping'), icon: Icons.storefront_outlined),
        const SizedBox(height: 8),
        _SourceTile(name: t('Weitere Portale', 'More portals'), status: t('Adapter vorbereitet: AT/CH/FR/NL/PL + weitere', 'Adapter-ready: AT/CH/FR/NL/PL + more'), icon: Icons.hub_outlined),
        const SizedBox(height: 18),
        _TipCard(icon: Icons.security_outlined, title: t('Warum Backend?', 'Why a backend?'), body: t('Marketplace-Schlüssel gehören nicht in die APK. FlipRadar lädt eBay-Livedaten deshalb über einen eigenen Server-Adapter. So bleiben Zugangsdaten geschützt und weitere Portale können sauber ergänzt werden.', 'Marketplace secrets do not belong in the APK. FlipRadar therefore loads eBay live data through its own server adapter. This protects credentials and makes additional portals easier to add.')),
        const SizedBox(height: 14),
        const Text('FlipRadar V0.3 • Research build', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
      ]);
}

class _SourceTile extends StatelessWidget {
  final String name;
  final String status;
  final IconData icon;
  const _SourceTile({required this.name, required this.status, required this.icon});

  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(status), trailing: const Icon(Icons.check_circle_outline)));
}
