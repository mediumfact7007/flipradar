import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlipRadarApp());
}

class FlipRadarApp extends StatefulWidget {
  const FlipRadarApp({super.key});
  @override
  State<FlipRadarApp> createState() => _FlipRadarAppState();
}

class _FlipRadarAppState extends State<FlipRadarApp> {
  bool en = false, ready = false;
  String keepa = '', backend = '';
  double targetRoi = 35;
  final flips = <FlipItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final restored = <FlipItem>[];
    for (final s in p.getStringList('flips04') ?? <String>[]) {
      try {
        restored.add(FlipItem.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    setState(() {
      en = p.getBool('en') ?? false;
      keepa = p.getString('keepa') ?? '';
      backend = p.getString('backend') ?? '';
      targetRoi = p.getDouble('targetRoi') ?? 35;
      flips.addAll(restored);
      ready = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('en', en);
    await p.setString('keepa', keepa);
    await p.setString('backend', backend);
    await p.setDouble('targetRoi', targetRoi);
    await p.setStringList(
      'flips04',
      flips.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF5746E8),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: ready
          ? Shell(
              en: en,
              keepa: keepa,
              backend: backend,
              targetRoi: targetRoi,
              flips: flips,
              onEn: (v) {
                setState(() => en = v);
                _save();
              },
              onKeepa: (v) {
                setState(() => keepa = v);
                _save();
              },
              onBackend: (v) {
                setState(() => backend = v);
                _save();
              },
              onRoi: (v) {
                setState(() => targetRoi = v);
                _save();
              },
              onAddFlip: (f) {
                setState(() => flips.insert(0, f));
                _save();
              },
              onUpdateFlip: (i, f) {
                setState(() => flips[i] = f);
                _save();
              },
            )
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}

class FlipItem {
  final String name, status;
  final double buy, sell, costs;
  const FlipItem(this.name, this.buy, this.sell, this.costs, this.status);
  double get profit => sell - buy - costs;
  double get roi => buy <= 0 ? 0 : profit / buy * 100;
  FlipItem withStatus(String s) => FlipItem(name, buy, sell, costs, s);
  Map<String, dynamic> toJson() => {
        'name': name,
        'buy': buy,
        'sell': sell,
        'costs': costs,
        'status': status,
      };
  factory FlipItem.fromJson(Map<String, dynamic> j) => FlipItem(
        j['name']?.toString() ?? 'Item',
        (j['buy'] as num?)?.toDouble() ?? 0,
        (j['sell'] as num?)?.toDouble() ?? 0,
        (j['costs'] as num?)?.toDouble() ?? 0,
        j['status']?.toString() ?? 'Bought',
      );
}

class Snap {
  final String source, title, detail;
  final double? price, min, max, median;
  final int count;
  final bool live;
  const Snap(
    this.source,
    this.title,
    this.detail, {
    this.price,
    this.min,
    this.max,
    this.median,
    this.count = 0,
    this.live = true,
  });
}

class Shell extends StatefulWidget {
  final bool en;
  final String keepa, backend;
  final double targetRoi;
  final List<FlipItem> flips;
  final ValueChanged<bool> onEn;
  final ValueChanged<String> onKeepa, onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<FlipItem> onAddFlip;
  final void Function(int, FlipItem) onUpdateFlip;
  const Shell({
    super.key,
    required this.en,
    required this.keepa,
    required this.backend,
    required this.targetRoi,
    required this.flips,
    required this.onEn,
    required this.onKeepa,
    required this.onBackend,
    required this.onRoi,
    required this.onAddFlip,
    required this.onUpdateFlip,
  });
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String query = '';
  String t(String de, String en) => widget.en ? en : de;
  void market(String q) {
    setState(() {
      query = q;
      tab = 1;
    });
  }

  @override
  Widget build(BuildContext c) {
    final pages = [
      Home(
        en: widget.en,
        flips: widget.flips,
        onMarket: market,
        onScan: () => setState(() => tab = 2),
      ),
      Market(
        key: ValueKey(query),
        en: widget.en,
        initial: query,
        keepa: widget.keepa,
        backend: widget.backend,
        targetRoi: widget.targetRoi,
        onAddFlip: widget.onAddFlip,
      ),
      Scanner(en: widget.en, onCode: market),
      Flips(
        en: widget.en,
        flips: widget.flips,
        onUpdate: widget.onUpdateFlip,
      ),
      Setup(
        en: widget.en,
        keepa: widget.keepa,
        backend: widget.backend,
        targetRoi: widget.targetRoi,
        onEn: widget.onEn,
        onKeepa: widget.onKeepa,
        onBackend: widget.onBackend,
        onRoi: widget.onRoi,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: t('Start', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.radar),
            label: t('Markt', 'Market'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Flips',
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune),
            label: t('Setup', 'Setup'),
          ),
        ],
      ),
    );
  }
}

class Home extends StatefulWidget {
  final bool en;
  final List<FlipItem> flips;
  final ValueChanged<String> onMarket;
  final VoidCallback onScan;
  const Home({
    super.key,
    required this.en,
    required this.flips,
    required this.onMarket,
    required this.onScan,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final q = TextEditingController();
  String t(String de, String en) => widget.en ? en : de;
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final sold = widget.flips.where((e) => e.status == 'Sold');
    final profit = sold.fold<double>(0, (a, b) => a + b.profit);
    final capital = widget.flips
        .where((e) => e.status != 'Sold')
        .fold<double>(0, (a, b) => a + b.buy);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header('FlipRadar', t('Live Preisradar für Reselling', 'Live price radar for reselling')),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B1746), Color(0xFF5947EC)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              stat(t('Gewinn', 'Profit'), '${profit.toStringAsFixed(0)} €', true),
              stat(t('Kapital', 'Capital'), '${capital.toStringAsFixed(0)} €', true),
              stat('Flips', '${widget.flips.length}', true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: q,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onMarket(v.trim());
          },
          decoration: InputDecoration(
            hintText: t('Produkt, Modell, EAN oder ASIN', 'Product, model, EAN or ASIN'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: widget.onScan,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            if (q.text.trim().isNotEmpty) widget.onMarket(q.text.trim());
          },
          icon: const Icon(Icons.travel_explore),
          label: Text(t('Live Preise vergleichen', 'Compare live prices')),
        ),
        const SizedBox(height: 24),
        Text(
          t('Quellen', 'Sources'),
          style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['eBay DE', 'Kleinanzeigen', 'Amazon DE', 'MediaMarkt', 'SATURN', 'idealo']
              .map((e) => Chip(
                    label: Text(e),
                    avatar: const Icon(Icons.check_circle_outline, size: 17),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        note(t(
          'Live-API-Preise werden nur angezeigt, wenn die jeweilige offizielle oder zulässige Datenquelle verbunden ist. Sonst öffnet FlipRadar die echte Suche des Portals.',
          'Live API prices are only shown when an official or permitted data source is connected. Otherwise FlipRadar opens the portal’s real search.',
        )),
      ],
    );
  }
}

class Scanner extends StatefulWidget {
  final bool en;
  final ValueChanged<String> onCode;
  const Scanner({super.key, required this.en, required this.onCode});
  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  bool done = false;
  String t(String de, String en) => widget.en ? en : de;
  @override
  Widget build(BuildContext c) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: header(
              t('Barcode scannen', 'Scan barcode'),
              t('EAN oder UPC erfassen und direkt vergleichen', 'Capture EAN or UPC and compare instantly'),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: (cap) {
                        if (done || cap.barcodes.isEmpty) return;
                        final v = cap.barcodes.first.rawValue?.trim();
                        if (v == null || v.isEmpty) return;
                        done = true;
                        widget.onCode(v);
                      },
                    ),
                    Center(
                      child: Container(
                        width: 270,
                        height: 170,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class Market extends StatefulWidget {
  final bool en;
  final String initial, keepa, backend;
  final double targetRoi;
  final ValueChanged<FlipItem> onAddFlip;
  const Market({
    super.key,
    required this.en,
    required this.initial,
    required this.keepa,
    required this.backend,
    required this.targetRoi,
    required this.onAddFlip,
  });
  @override
  State<Market> createState() => _MarketState();
}

class _MarketState extends State<Market> {
  late final TextEditingController q;
  final buy = TextEditingController();
  final fees = TextEditingController(text: '0');
  final shipping = TextEditingController(text: '6');
  final other = TextEditingController(text: '0');
  final snaps = <Snap>[];
  bool loading = false;
  String? error;

  String t(String de, String en) => widget.en ? en : de;
  double n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    q = TextEditingController(text: widget.initial);
    if (widget.initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => lookup());
    }
  }

  @override
  void dispose() {
    for (final x in [q, buy, fees, shipping, other]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> lookup() async {
    final term = q.text.trim();
    if (term.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      snaps.clear();
    });
    final errs = <String>[];
    if (widget.keepa.trim().isNotEmpty) {
      try {
        final s = await keepa(term);
        if (s != null) snaps.add(s);
      } catch (e) {
        errs.add('Amazon/Keepa: $e');
      }
    }
    if (widget.backend.trim().isNotEmpty) {
      try {
        final s = await ebay(term);
        if (s != null) snaps.add(s);
      } catch (e) {
        errs.add('eBay: $e');
      }
    }
    setState(() {
      loading = false;
      if (errs.isNotEmpty) error = errs.join('\n');
    });
  }

  Future<Snap?> keepa(String term) async {
    final clean = term.trim();
    final isAsin = RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(clean);
    final isCode = RegExp(r'^\d{8,14}$').hasMatch(clean);
    if (!isAsin && !isCode) {
      return Snap(
        'Amazon DE / Keepa',
        clean,
        t('Für Live-Keepa EAN, UPC oder ASIN verwenden.', 'Use EAN, UPC or ASIN for live Keepa.'),
        live: false,
      );
    }
    final params = <String, String>{
      'key': widget.keepa.trim(),
      'domain': '3',
      'stats': '90',
      'history': '0',
    };
    if (isAsin) {
      params['asin'] = clean.toUpperCase();
    } else {
      params['code'] = clean;
    }
    final r = await http
        .get(
          Uri.https('api.keepa.com', '/product', params),
          headers: {'Accept-Encoding': 'gzip'},
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final products = d['products'];
    if (products is! List || products.isEmpty) {
      throw Exception(t('kein Treffer', 'no match'));
    }
    final p = products.first as Map<String, dynamic>;
    double? amazon, newPrice, used;
    final st = p['stats'];
    if (st is Map<String, dynamic> && st['current'] is List) {
      final cur = st['current'] as List;
      double? at(int i) {
        if (i >= cur.length) return null;
        final raw = cur[i];
        if (raw is num && raw > 0) return raw.toDouble() / 100;
        return null;
      }
      amazon = at(0);
      newPrice = at(1);
      used = at(2);
    }
    final vals = [amazon, newPrice, used].whereType<double>().toList()..sort();
    double? med;
    if (vals.isNotEmpty) {
      med = vals.length.isOdd
          ? vals[vals.length ~/ 2]
          : (vals[vals.length ~/ 2 - 1] + vals[vals.length ~/ 2]) / 2;
    }
    return Snap(
      'Amazon DE / Keepa',
      p['title']?.toString() ?? clean,
      t(
        'Amazon: ${money(amazon)} · Neu: ${money(newPrice)} · Gebraucht: ${money(used)}',
        'Amazon: ${money(amazon)} · New: ${money(newPrice)} · Used: ${money(used)}',
      ),
      price: amazon ?? newPrice ?? used,
      min: vals.isEmpty ? null : vals.first,
      max: vals.isEmpty ? null : vals.last,
      median: med,
      count: vals.length,
    );
  }

  Future<Snap?> ebay(String term) async {
    final base = widget.backend.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/market/ebay').replace(
      queryParameters: {'q': term, 'marketplace': 'EBAY_DE'},
    );
    final r = await http.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return Snap(
      'eBay DE',
      term,
      t(
        'Aktive eBay-Angebote via offiziellem Browse-API-Adapter.',
        'Active eBay listings via official Browse API adapter.',
      ),
      price: (d['median'] as num?)?.toDouble(),
      median: (d['median'] as num?)?.toDouble(),
      min: (d['min'] as num?)?.toDouble(),
      max: (d['max'] as num?)?.toDouble(),
      count: (d['count'] as num?)?.toInt() ?? 0,
    );
  }

  static String money(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} €';

  double? get ref {
    final v = snaps
        .expand((s) => [s.median, s.price])
        .whereType<double>()
        .where((x) => x > 0)
        .toList()
      ..sort();
    if (v.isEmpty) return null;
    return v[v.length ~/ 2];
  }

  double? get buyMax {
    if (ref == null) return null;
    final fixed = n(fees) + n(shipping) + n(other);
    return math.max(0.0, (ref! - fixed) / (1 + widget.targetRoi / 100)).toDouble();
  }

  String url(String source, String term) {
    final e = Uri.encodeQueryComponent(term);
    switch (source) {
      case 'eBay DE':
        return 'https://www.ebay.de/sch/i.html?_nkw=$e';
      case 'Kleinanzeigen':
        final slug = term
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        return 'https://www.kleinanzeigen.de/s-$slug/k0';
      case 'Amazon DE':
        return 'https://www.amazon.de/s?k=$e';
      case 'MediaMarkt':
        return 'https://www.mediamarkt.de/de/search.html?query=$e';
      case 'SATURN':
        return 'https://www.saturn.de/de/search.html?query=$e';
      default:
        return 'https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q=$e';
    }
  }

  Future<void> open(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext c) {
    final sell = ref ?? 0;
    final b = n(buy);
    final cost = n(fees) + n(shipping) + n(other);
    final profit = sell - b - cost;
    final roi = b <= 0 ? 0 : profit / b * 100;
    final sources = ['eBay DE', 'Kleinanzeigen', 'Amazon DE', 'MediaMarkt', 'SATURN', 'idealo'];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(
          t('Live-Markt', 'Live market'),
          t('Ein Produkt über mehrere Portale prüfen', 'Check one product across multiple portals'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: q,
          onSubmitted: (_) => lookup(),
          decoration: InputDecoration(
            hintText: t('Produkt, EAN, UPC oder ASIN', 'Product, EAN, UPC or ASIN'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(onPressed: lookup, icon: const Icon(Icons.refresh)),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: loading ? null : lookup,
          icon: const Icon(Icons.radar),
          label: Text(t('API-Daten abrufen', 'Fetch API data')),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          note(error!),
        ],
        const SizedBox(height: 18),
        Text(
          t('Live-Daten', 'Live data'),
          style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (snaps.isEmpty)
          note(t(
            'Noch keine API verbunden oder kein Treffer. Die Portal-Suche darunter funktioniert trotzdem live.',
            'No API connected or no match yet. Portal search below still works live.',
          )),
        ...snaps.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.source, style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        Chip(label: Text(s.live ? 'LIVE' : 'INFO')),
                      ],
                    ),
                    Text(s.title),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        stat(t('Preis', 'Price'), money(s.price)),
                        stat('Median', money(s.median)),
                        stat(t('Treffer', 'Count'), '${s.count}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(s.detail, style: Theme.of(c).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t('Portale live öffnen', 'Open live portals'),
          style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(s, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  s == 'eBay DE'
                      ? t('API-ready + echte Websuche', 'API-ready + real web search')
                      : s == 'Amazon DE'
                          ? t('Keepa optional + echte Websuche', 'Optional Keepa + real web search')
                          : t('Echte Websuche, keine inoffizielle API', 'Real web search, no unofficial API'),
                ),
                trailing: IconButton(
                  onPressed: q.text.trim().isEmpty ? null : () => open(url(s, q.text.trim())),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t('Deal-Rechner', 'Deal calculator'),
          style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: moneyField(buy, t('Einkauf', 'Buy'), () => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: moneyField(fees, t('Gebühren', 'Fees'), () => setState(() {}))),
          ],
        ),
        Row(
          children: [
            Expanded(child: moneyField(shipping, t('Versand', 'Shipping'), () => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: moneyField(other, t('Sonstiges', 'Other'), () => setState(() {}))),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                stat('BUY MAX', money(buyMax)),
                stat(t('Gewinn', 'Profit'), ref == null ? '—' : '${profit.toStringAsFixed(2)} €'),
                stat('ROI', ref == null || b <= 0 ? '—' : '${roi.toStringAsFixed(1)} %'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'BUY MAX nutzt ${widget.targetRoi.toStringAsFixed(0)} % Ziel-ROI.',
            'BUY MAX uses ${widget.targetRoi.toStringAsFixed(0)}% target ROI.',
          ),
          style: Theme.of(c).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ref == null || q.text.trim().isEmpty
              ? null
              : () {
                  widget.onAddFlip(FlipItem(q.text.trim(), b, ref!, cost, 'Bought'));
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(t('Flip gespeichert', 'Flip saved'))),
                  );
                },
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(t('Als Flip speichern', 'Save as flip')),
        ),
      ],
    );
  }
}

class Flips extends StatelessWidget {
  final bool en;
  final List<FlipItem> flips;
  final void Function(int, FlipItem) onUpdate;
  const Flips({super.key, required this.en, required this.flips, required this.onUpdate});
  String t(String de, String en) => this.en ? en : de;
  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          header(t('Meine Flips', 'My flips'), t('Bestand, Status und Marge', 'Inventory, status and margin')),
          const SizedBox(height: 14),
          if (flips.isEmpty) note(t('Noch keine Flips gespeichert.', 'No flips saved yet.')),
          ...flips.asMap().entries.map((e) {
            final f = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${f.buy.toStringAsFixed(0)} € → ${f.sell.toStringAsFixed(0)} € · ${f.profit >= 0 ? '+' : ''}${f.profit.toStringAsFixed(0)} € · ${f.roi.toStringAsFixed(0)} %',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (s) => onUpdate(e.key, f.withStatus(s)),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'Bought', child: Text(t('Gekauft', 'Bought'))),
                      PopupMenuItem(value: 'Listed', child: Text(t('Inseriert', 'Listed'))),
                      PopupMenuItem(value: 'Sold', child: Text(t('Verkauft', 'Sold'))),
                    ],
                    child: Chip(label: Text(f.status)),
                  ),
                ),
              ),
            );
          }),
        ],
      );
}

class Setup extends StatefulWidget {
  final bool en;
  final String keepa, backend;
  final double targetRoi;
  final ValueChanged<bool> onEn;
  final ValueChanged<String> onKeepa, onBackend;
  final ValueChanged<double> onRoi;
  const Setup({
    super.key,
    required this.en,
    required this.keepa,
    required this.backend,
    required this.targetRoi,
    required this.onEn,
    required this.onKeepa,
    required this.onBackend,
    required this.onRoi,
  });
  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  late final TextEditingController k, b;
  String t(String de, String en) => widget.en ? en : de;
  @override
  void initState() {
    super.initState();
    k = TextEditingController(text: widget.keepa);
    b = TextEditingController(text: widget.backend);
  }

  @override
  void dispose() {
    k.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          header(
            t('Datenquellen & Setup', 'Data sources & setup'),
            t('Live-Zugänge verbinden', 'Connect live data access'),
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              title: const Text('English'),
              value: widget.en,
              onChanged: widget.onEn,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amazon DE via Keepa', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(t(
                    'Optional: Keepa liefert Amazon-Preis- und Historiedaten. Der Key bleibt lokal auf diesem Testgerät.',
                    'Optional: Keepa supplies Amazon price and history data. The key stays locally on this test device.',
                  )),
                  const SizedBox(height: 10),
                  TextField(
                    controller: k,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Keepa API key',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => widget.onKeepa(k.text.trim()),
                    child: Text(t('Speichern', 'Save')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('eBay DE Backend', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(t(
                    'eBay-Secret gehört nicht in die APK. Trage die URL des FlipRadar-Backends ein.',
                    'The eBay secret must not be stored in the APK. Enter the FlipRadar backend URL.',
                  )),
                  const SizedBox(height: 10),
                  TextField(
                    controller: b,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Backend URL',
                      hintText: 'https://api.example.com',
                      prefixIcon: Icon(Icons.cloud_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => widget.onBackend(b.text.trim()),
                    child: Text(t('Speichern', 'Save')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Ziel-ROI', 'Target ROI'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Slider(
                    value: widget.targetRoi.clamp(10, 100).toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${widget.targetRoi.toStringAsFixed(0)} %',
                    onChanged: widget.onRoi,
                  ),
                  Text('${widget.targetRoi.toStringAsFixed(0)} %'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          note(t(
            'MediaMarkt und SATURN: Partner- und Produktfeeds sind vorbereitet, aber erst nach Freigabe des jeweiligen Partnerprogramms automatisch abrufbar. Kleinanzeigen wird bewusst nicht über private oder reverse-engineerte APIs gescraped.',
            'MediaMarkt and SATURN: partner and product feeds are prepared, but automated retrieval requires partner-program approval. Kleinanzeigen is intentionally not scraped through private or reverse-engineered APIs.',
          )),
        ],
      );
}

Widget header(String title, String sub) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(color: Colors.black54)),
      ],
    );

Widget stat(String label, String value, [bool dark = false]) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? Colors.white : null,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

Widget note(String text) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5D8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );

Widget moneyField(
  TextEditingController c,
  String label,
  VoidCallback changed,
) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => changed(),
        decoration: InputDecoration(labelText: '$label €'),
      ),
    );
