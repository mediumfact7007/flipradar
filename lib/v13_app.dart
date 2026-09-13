import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'source_registry.dart';
import 'v07.dart' show ScannerPage, UserPlan;

const _v13Primary = Color(0xFF4E50D8);
const _v13Ink = Color(0xFF20213F);
const _v13Bg = Color(0xFFF6F7FB);

String v13Euro(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.005) return '${rounded.toStringAsFixed(0)} €';
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
}

double v13Money(String raw) {
  var value = raw
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (value.isEmpty) return 0;
  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    value = comma > dot
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value.replaceAll(',', '');
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
  return parsed == null || !parsed.isFinite || parsed < 0 ? 0 : parsed;
}

enum V13InputKind { text, url, ean, asin }

class V13SearchInput {
  final String raw;
  final String query;
  final V13InputKind kind;
  final String? correction;

  const V13SearchInput({required this.raw, required this.query, required this.kind, this.correction});
}

String _slugWords(String raw) => Uri.decodeComponent(raw)
    .replaceAll(RegExp(r'[-_+]+'), ' ')
    .replaceAll(RegExp(r'\b\d{7,}\b'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _commonCorrection(String input) {
  var value = input;
  const replacements = <String, String>{
    'iphnoe': 'iphone',
    'ipohne': 'iphone',
    'appel': 'apple',
    'samsng': 'samsung',
    'samsun': 'samsung',
    'playstaion': 'playstation',
    'playstion': 'playstation',
    'nintedo': 'nintendo',
    'makitta': 'makita',
    'airpod': 'airpods',
  };
  final words = value.split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final lower = words[i].toLowerCase();
    final replacement = replacements[lower];
    if (replacement != null) {
      final original = words[i];
      words[i] = RegExp(r'^[A-Z]').hasMatch(original)
          ? '${replacement[0].toUpperCase()}${replacement.substring(1)}'
          : replacement;
    }
  }
  return words.join(' ');
}

V13SearchInput normalizeV13Search(String rawInput) {
  final raw = rawInput.trim();
  if (raw.isEmpty) return const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);

  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(r'^\d{8,14}$').hasMatch(compact)) {
    return V13SearchInput(raw: raw, query: compact, kind: V13InputKind.ean);
  }
  if (RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(compact) && RegExp(r'[A-Z]', caseSensitive: false).hasMatch(compact)) {
    return V13SearchInput(raw: raw, query: compact.toUpperCase(), kind: V13InputKind.asin);
  }

  final urlMatch = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(compact);
  if (urlMatch != null) {
    final before = compact.substring(0, urlMatch.start).trim();
    final cleanBefore = before
        .replaceAll(RegExp(r'\b\d{1,5}(?:[.,]\d{1,2})?\s*€\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanBefore.length >= 4 && !cleanBefore.toLowerCase().contains('gerade bei')) {
      final corrected = _commonCorrection(cleanBefore);
      return V13SearchInput(
        raw: raw,
        query: corrected,
        kind: V13InputKind.url,
        correction: corrected == cleanBefore ? null : corrected,
      );
    }

    final uri = Uri.tryParse(urlMatch.group(0)!);
    if (uri != null) {
      for (final key in ['_nkw', 'q', 'query', 'search_text', 'fs', 'k']) {
        final value = uri.queryParameters[key];
        if (value != null && value.trim().isNotEmpty) {
          final query = _commonCorrection(_slugWords(value));
          return V13SearchInput(raw: raw, query: query, kind: V13InputKind.url);
        }
      }
      final path = uri.path;
      final asin = RegExp(r'/(?:dp|gp/product)/([A-Z0-9]{10})(?:/|$)', caseSensitive: false).firstMatch(path);
      if (asin != null) {
        return V13SearchInput(raw: raw, query: asin.group(1)!.toUpperCase(), kind: V13InputKind.asin);
      }
      if (uri.host.contains('kleinanzeigen')) {
        final match = RegExp(r'/s-anzeige/([^/]+)').firstMatch(path);
        if (match != null) {
          return V13SearchInput(raw: raw, query: _commonCorrection(_slugWords(match.group(1)!)), kind: V13InputKind.url);
        }
      }
      if (uri.host.contains('ebay.')) {
        final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
        if (segments.length >= 2 && segments.first != 'itm') {
          final candidate = _slugWords(segments[segments.length - 2]);
          if (candidate.length >= 4) return V13SearchInput(raw: raw, query: _commonCorrection(candidate), kind: V13InputKind.url);
        }
      }
      final slug = uri.pathSegments.reversed.firstWhere(
        (e) => e.length >= 5 && !RegExp(r'^\d+$').hasMatch(e),
        orElse: () => '',
      );
      if (slug.isNotEmpty) return V13SearchInput(raw: raw, query: _commonCorrection(_slugWords(slug)), kind: V13InputKind.url);
    }
  }

  final corrected = _commonCorrection(compact);
  return V13SearchInput(
    raw: raw,
    query: corrected,
    kind: V13InputKind.text,
    correction: corrected == compact ? null : corrected,
  );
}

String v13Category(String raw) {
  final q = raw.toLowerCase();
  if (RegExp(r'(iphone|samsung|galaxy|pixel|smartphone|handy)').hasMatch(q)) return 'Smartphone';
  if (RegExp(r'(macbook|laptop|notebook|thinkpad|surface)').hasMatch(q)) return 'Laptop';
  if (RegExp(r'(playstation|ps5|xbox|switch|konsole)').hasMatch(q)) return 'Konsole';
  if (RegExp(r'(nike|adidas|jordan|yeezy|sneaker|schuh)').hasMatch(q)) return 'Sneaker';
  if (RegExp(r'(kamera|canon|nikon|sony alpha|objektiv|lens)').hasMatch(q)) return 'Kamera';
  if (RegExp(r'(makita|bosch|festool|dewalt|milwaukee|werkzeug)').hasMatch(q)) return 'Werkzeug';
  if (RegExp(r'(airpods|kopfhörer|headphone|speaker|lautsprecher)').hasMatch(q)) return 'Audio';
  if (RegExp(r'(lego|pokemon|karte|sammler|collect)').hasMatch(q)) return 'Sammler';
  if (RegExp(r'(jacke|hose|shirt|kleid|pullover|tasche|gucci|prada|vuitton)').hasMatch(q)) return 'Mode';
  return 'Sonstiges';
}

class V13Flip {
  final String id;
  final String name;
  final String category;
  final double buy;
  final double expectedAtBuy;
  final double costs;
  final int sourceCount;
  final String confidence;
  final String status;
  final DateTime createdAt;
  final DateTime? listedAt;
  final DateTime? soldAt;
  final double actualSell;
  final String soldPlatform;

  const V13Flip({
    required this.id,
    required this.name,
    required this.category,
    required this.buy,
    required this.expectedAtBuy,
    required this.costs,
    required this.sourceCount,
    required this.confidence,
    required this.status,
    required this.createdAt,
    this.listedAt,
    this.soldAt,
    this.actualSell = 0,
    this.soldPlatform = '',
  });

  double get realizedProfit => actualSell > 0 ? actualSell - buy - costs : 0;
  double get realizedRoi => buy <= 0 ? 0 : realizedProfit / buy * 100;
  int? get daysToSell => soldAt == null ? null : math.max(0, soldAt!.difference(createdAt).inDays);

  V13Flip copyWith({
    String? status,
    DateTime? listedAt,
    DateTime? soldAt,
    double? actualSell,
    String? soldPlatform,
  }) =>
      V13Flip(
        id: id,
        name: name,
        category: category,
        buy: buy,
        expectedAtBuy: expectedAtBuy,
        costs: costs,
        sourceCount: sourceCount,
        confidence: confidence,
        status: status ?? this.status,
        createdAt: createdAt,
        listedAt: listedAt ?? this.listedAt,
        soldAt: soldAt ?? this.soldAt,
        actualSell: actualSell ?? this.actualSell,
        soldPlatform: soldPlatform ?? this.soldPlatform,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'buy': buy,
        'expectedAtBuy': expectedAtBuy,
        'costs': costs,
        'sourceCount': sourceCount,
        'confidence': confidence,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'listedAt': listedAt?.toIso8601String(),
        'soldAt': soldAt?.toIso8601String(),
        'actualSell': actualSell,
        'soldPlatform': soldPlatform,
      };

  factory V13Flip.fromJson(Map<String, dynamic> j) {
    final status = j['status']?.toString() ?? 'Bought';
    final legacySell = (j['sell'] as num?)?.toDouble() ?? 0;
    final actual = (j['actualSell'] as num?)?.toDouble() ?? (status == 'Sold' ? legacySell : 0);
    return V13Flip(
      id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: j['name']?.toString() ?? 'Artikel',
      category: j['category']?.toString() ?? v13Category(j['name']?.toString() ?? ''),
      buy: (j['buy'] as num?)?.toDouble() ?? 0,
      expectedAtBuy: (j['expectedAtBuy'] as num?)?.toDouble() ?? (status == 'Sold' ? legacySell : legacySell),
      costs: (j['costs'] as num?)?.toDouble() ?? 0,
      sourceCount: (j['sourceCount'] as num?)?.toInt() ?? 0,
      confidence: j['confidence']?.toString() ?? 'Unbekannt',
      status: status,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      listedAt: DateTime.tryParse(j['listedAt']?.toString() ?? ''),
      soldAt: DateTime.tryParse(j['soldAt']?.toString() ?? '') ?? (status == 'Sold' ? DateTime.tryParse(j['createdAt']?.toString() ?? '') : null),
      actualSell: actual,
      soldPlatform: j['soldPlatform']?.toString() ?? '',
    );
  }
}

class V13PersonalStats {
  final int sample;
  final double? avgDays;
  final double? avgRoi;
  final double? saleFactor;

  const V13PersonalStats({required this.sample, this.avgDays, this.avgRoi, this.saleFactor});

  factory V13PersonalStats.forCategory(List<V13Flip> flips, String category) {
    final sold = flips.where((f) => f.status == 'Sold' && f.actualSell > 0 && f.category == category).toList();
    if (sold.isEmpty) return const V13PersonalStats(sample: 0);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final rois = sold.where((e) => e.buy > 0).map((e) => e.realizedRoi).toList();
    final factors = sold
        .where((e) => e.expectedAtBuy > 0)
        .map((e) => e.actualSell / e.expectedAtBuy)
        .where((e) => e.isFinite && e > 0)
        .toList()
      ..sort();
    final factor = factors.isEmpty
        ? null
        : factors.length.isOdd
            ? factors[factors.length ~/ 2]
            : (factors[factors.length ~/ 2 - 1] + factors[factors.length ~/ 2]) / 2;
    return V13PersonalStats(
      sample: sold.length,
      avgDays: days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length,
      avgRoi: rois.isEmpty ? null : rois.reduce((a, b) => a + b) / rois.length,
      saleFactor: factor?.clamp(.82, 1.15).toDouble(),
    );
  }

  String speedLabel(bool english) {
    if (avgDays == null || sample < 2) return english ? 'Unknown' : 'Offen';
    if (avgDays! <= 14) return english ? 'Fast' : 'Schnell';
    if (avgDays! <= 45) return english ? 'Medium' : 'Mittel';
    return english ? 'Slow' : 'Langsam';
  }
}

enum V13TaxMode { privateSeller, smallBusiness, business, marginScheme }

String v13TaxLabel(V13TaxMode mode, bool english) {
  switch (mode) {
    case V13TaxMode.privateSeller:
      return english ? 'Private' : 'Privat';
    case V13TaxMode.smallBusiness:
      return english ? 'Small business' : 'Kleinunternehmer';
    case V13TaxMode.business:
      return english ? 'Business' : 'Gewerblich';
    case V13TaxMode.marginScheme:
      return english ? 'Margin scheme' : 'Differenzbesteuerung';
  }
}

class V13StoreProduct {
  final String id;
  final String price;
  const V13StoreProduct({required this.id, required this.price});
}

class V13Monetization extends ChangeNotifier {
  static const monthlyId = 'flipradar_pro_monthly';
  static const yearlyId = 'flipradar_pro_yearly';

  final VoidCallback onProUnlocked;
  bool adsAllowed = false;
  bool billingAvailable = false;
  bool loadingBilling = false;
  List<V13StoreProduct> products = const [];

  V13Monetization({required this.onProUnlocked});

  // SAFE START: no native ads/billing SDK is touched. This deliberately keeps
  // startup independent from Google Play Services and ad-consent state.
  Future<void> init() async {}
  Future<void> showPrivacyOptions() async {}

  V13StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(V13StoreProduct product) async {}
  Future<void> restore() async {}
  Future<bool> rewardedUnlock() async => false;
}

class FlipRadarV13App extends StatefulWidget {
  const FlipRadarV13App({super.key});

  @override
  State<FlipRadarV13App> createState() => _FlipRadarV13AppState();
}

class _FlipRadarV13AppState extends State<FlipRadarV13App> {
  bool loading = true;
  bool english = false;
  String backend = '';
  double targetRoi = 35;
  double minProfit = 20;
  UserPlan plan = UserPlan.free;
  V13TaxMode taxMode = V13TaxMode.privateSeller;
  List<V13Flip> flips = [];
  List<String> history = [];
  List<PriceSource> sources = [];
  late final V13Monetization monetization;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    monetization = V13Monetization(onProUnlocked: _unlockPro);
    unawaited(_loadSafe());
  }

  Future<void> _loadSafe() async {
    try {
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // A corrupt/incompatible preference from an older prototype must never
        // prevent FlipRadar from opening. Start with sane local defaults.
        english = false;
        backend = '';
        targetRoi = 35;
        minProfit = 20;
        plan = UserPlan.free;
        taxMode = V13TaxMode.privateSeller;
        flips = <V13Flip>[];
        history = <String>[];
        sources = SourceRegistry.builtIns();
        loading = false;
      });
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFlips = prefs.getStringList('flips_v13') ??
        prefs.getStringList('flips_v10') ??
        prefs.getStringList('flips_v09') ??
        prefs.getStringList('flips_v08') ??
        <String>[];
    final loadedFlips = <V13Flip>[];
    for (final raw in rawFlips) {
      try {
        loadedFlips.add(V13Flip.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    final loadedBackend = prefs.getString('backend_v13') ?? prefs.getString('backend_v10') ?? '';
    final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
    final rawPlan = prefs.getInt('plan_v13') ?? prefs.getInt('plan_preview_v10') ?? 0;
    final rawTax = prefs.getInt('tax_mode_v13') ?? 0;
    if (!mounted) return;
    setState(() {
      english = prefs.getBool('english_v13') ?? prefs.getBool('english_v10') ?? false;
      backend = loadedBackend;
      targetRoi = (prefs.getDouble('roi_v13') ?? prefs.getDouble('roi_v10') ?? 35).clamp(10, 100).toDouble();
      minProfit = (prefs.getDouble('min_profit_v13') ?? prefs.getDouble('min_profit_v12') ?? 20).clamp(0, 500).toDouble();
      plan = rawPlan <= 0 ? UserPlan.free : UserPlan.pro;
      taxMode = V13TaxMode.values[rawTax.clamp(0, V13TaxMode.values.length - 1)];
      flips = loadedFlips;
      history = (prefs.getStringList('history_v13') ?? prefs.getStringList('history_v10') ?? <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .take(12)
          .toList();
      sources = loadedSources;
      loading = false;
    });
  }

  void _unlockPro() {
    if (!mounted) return;
    setState(() => plan = UserPlan.pro);
    _save();
  }

  void _save() {
    _saveQueue = _saveQueue.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setBool('english_v13', english);
      await p.setString('backend_v13', backend);
      await p.setDouble('roi_v13', targetRoi);
      await p.setDouble('min_profit_v13', minProfit);
      await p.setInt('plan_v13', plan == UserPlan.free ? 0 : 1);
      await p.setInt('tax_mode_v13', taxMode.index);
      await p.setStringList('flips_v13', flips.map((e) => jsonEncode(e.toJson())).toList());
      await p.setStringList('history_v13', history.take(12).toList());
    }).catchError((_) {});
  }

  void _addHistory(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      history.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      history.insert(0, q);
      if (history.length > 12) history = history.take(12).toList();
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _v13Bg,
      colorScheme: ColorScheme.fromSeed(seedColor: _v13Primary, surface: _v13Bg),
      appBarTheme: const AppBarTheme(backgroundColor: _v13Bg, surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE4E6EE))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _v13Primary, width: 1.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );

    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : V13Shell(
              english: english,
              backend: backend,
              targetRoi: targetRoi,
              minProfit: minProfit,
              plan: plan,
              taxMode: taxMode,
              flips: flips,
              history: history,
              sources: sources,
              monetization: monetization,
              onHistory: _addHistory,
              onAddFlip: (item) {
                setState(() => flips.insert(0, item));
                _save();
              },
              onUpdateFlip: (item) {
                final i = flips.indexWhere((e) => e.id == item.id);
                if (i >= 0) {
                  setState(() => flips[i] = item);
                  _save();
                }
              },
              onLanguage: (value) {
                setState(() => english = value);
                _save();
              },
              onRoi: (value) {
                setState(() => targetRoi = value.clamp(10, 100).toDouble());
                _save();
              },
              onMinProfit: (value) {
                setState(() => minProfit = value.clamp(0, 500).toDouble());
                _save();
              },
              onTaxMode: (value) {
                setState(() => taxMode = value);
                _save();
              },
              onBackend: (value) async {
                backend = value.trim();
                final loaded = await SourceRegistry.load(backendBase: backend);
                if (mounted) setState(() => sources = loaded);
                _save();
              },
              onSources: (value) {
                setState(() => sources = value);
                unawaited(SourceRegistry.save(value));
              },
              onPlanPreview: (value) {
                setState(() => plan = value == UserPlan.free ? UserPlan.free : UserPlan.pro);
                _save();
              },
            ),
    );
  }

  @override
  void dispose() {
    monetization.dispose();
    super.dispose();
  }
}

class V13Shell extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<V13Flip> flips;
  final List<String> history;
  final List<PriceSource> sources;
  final V13Monetization monetization;
  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
  final ValueChanged<V13Flip> onUpdateFlip;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<double> onRoi;
  final ValueChanged<double> onMinProfit;
  final ValueChanged<V13TaxMode> onTaxMode;
  final ValueChanged<String> onBackend;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<UserPlan> onPlanPreview;

  const V13Shell({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.minProfit,
    required this.plan,
    required this.taxMode,
    required this.flips,
    required this.history,
    required this.sources,
    required this.monetization,
    required this.onHistory,
    required this.onAddFlip,
    required this.onUpdateFlip,
    required this.onLanguage,
    required this.onRoi,
    required this.onMinProfit,
    required this.onTaxMode,
    required this.onBackend,
    required this.onSources,
    required this.onPlanPreview,
  });

  @override
  State<V13Shell> createState() => _V13ShellState();
}

class _V13ShellState extends State<V13Shell> {
  int tab = 0;
  bool opening = false;
  StreamSubscription<List<SharedMediaFile>>? shareSub;
  String lastShare = '';
  DateTime? lastShareAt;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    // Safe-start build: optional share listener is not part of first-frame startup.
  }

  // ignore: unused_element
  void _listenShares() {
    try {
      shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleShare, onError: (_) {});
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
    if (!mounted) return;
    for (final item in items) {
      final mime = item.mimeType ?? '';
      if (item.type == SharedMediaType.text || item.type == SharedMediaType.url || mime.startsWith('text/')) {
        final normalized = normalizeV13Search(item.path);
        if (normalized.query.isEmpty) return;
        final now = DateTime.now();
        if (normalized.query.toLowerCase() == lastShare.toLowerCase() && lastShareAt != null && now.difference(lastShareAt!).inSeconds < 4) return;
        lastShare = normalized.query;
        lastShareAt = now;
        unawaited(_openCheck(normalized.query));
        return;
      }
    }
  }

  Future<void> _openCheck(String raw) async {
    if (opening) return;
    final normalized = normalizeV13Search(raw);
    if (normalized.query.isEmpty) return;
    opening = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => V13CheckPage(
            english: widget.english,
            input: normalized,
            targetRoi: widget.targetRoi,
            minProfit: widget.minProfit,
            plan: widget.plan,
            taxMode: widget.taxMode,
            sources: widget.sources,
            flips: widget.flips,
            monetization: widget.monetization,
            onHistory: widget.onHistory,
            onAddFlip: widget.onAddFlip,
          ),
        ),
      );
    } finally {
      opening = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)));
    if (code != null && code.trim().isNotEmpty && mounted) await _openCheck(code);
  }

  Future<void> _settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => V13SettingsPage(
          english: widget.english,
          backend: widget.backend,
          targetRoi: widget.targetRoi,
          minProfit: widget.minProfit,
          plan: widget.plan,
          taxMode: widget.taxMode,
          sources: widget.sources,
          monetization: widget.monetization,
          onLanguage: widget.onLanguage,
          onRoi: widget.onRoi,
          onMinProfit: widget.onMinProfit,
          onTaxMode: widget.onTaxMode,
          onBackend: widget.onBackend,
          onSources: widget.onSources,
          onPlanPreview: widget.onPlanPreview,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      V13Home(
        english: widget.english,
        plan: widget.plan,
        history: widget.history,
        openFlips: widget.flips.where((e) => e.status != 'Sold').length,
        monetization: widget.monetization,
        onSearch: _openCheck,
        onScan: _scan,
        onSettings: _settings,
      ),
      V13FlipsPage(
        english: widget.english,
        plan: widget.plan,
        flips: widget.flips,
        monetization: widget.monetization,
        onUpdate: widget.onUpdateFlip,
        onPro: () => _openPaywall(context),
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: t('Prüfen', 'Check')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: t('Meine Flips', 'My flips')),
        ],
      ),
    );
  }

  Future<void> _openPaywall(BuildContext context) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: widget.english, monetization: widget.monetization)));
  }

  @override
  void dispose() {
    shareSub?.cancel();
    super.dispose();
  }
}

class V13Home extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<String> history;
  final int openFlips;
  final V13Monetization monetization;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;
  final VoidCallback onSettings;

  const V13Home({
    super.key,
    required this.english,
    required this.plan,
    required this.history,
    required this.openFlips,
    required this.monetization,
    required this.onSearch,
    required this.onScan,
    required this.onSettings,
  });

  @override
  State<V13Home> createState() => _V13HomeState();
}

class _V13HomeState extends State<V13Home> {
  final query = TextEditingController();
  V13SearchInput preview = const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);

  String t(String de, String en) => widget.english ? en : de;

  void _changed(String value) => setState(() => preview = normalizeV13Search(value));

  void _submit([String? value]) {
    final normalized = normalizeV13Search(value ?? query.text);
    if (normalized.query.isNotEmpty) widget.onSearch(normalized.query);
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    query.text = text.length > 500 ? text.substring(0, 500) : text;
    query.selection = TextSelection.collapsed(offset: query.text.length);
    _changed(query.text);
  }

  @override
  Widget build(BuildContext context) {
    final typed = query.text.trim().toLowerCase();
    final suggestions = widget.history
        .where((e) => typed.isEmpty || e.toLowerCase().contains(typed))
        .take(4)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            const Expanded(child: Text('FlipRadar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.6))),
            if (widget.plan != UserPlan.free)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: _V13Pill(text: 'PRO', foreground: Colors.white, background: _v13Primary),
              ),
            IconButton.filledTonal(onPressed: widget.onSettings, tooltip: t('Einstellungen', 'Settings'), icon: const Icon(Icons.tune_rounded)),
          ],
        ),
        const SizedBox(height: 25),
        Text(t('Artikel rein.\nEntscheidung raus.', 'Item in.\nDecision out.'), style: const TextStyle(fontSize: 34, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 9),
        Text(t('Suchen → Maximalpreis, Gewinn, Markt & Risiko.', 'Search → max buy, profit, market & risk.'), style: const TextStyle(fontSize: 14, color: Color(0xFF717585))),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('v13-universal-search'),
          controller: query,
          autofocus: true,
          onChanged: _changed,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: t('Produkt, Link, EAN oder ASIN', 'Product, link, EAN or ASIN'),
            hintText: t('z. B. Samsung Fold 8 512 GB', 'e.g. Samsung Fold 8 512 GB'),
            prefixIcon: const Icon(Icons.search_rounded, size: 25),
            suffixIcon: IconButton(onPressed: _paste, tooltip: t('Einfügen', 'Paste'), icon: const Icon(Icons.content_paste_rounded)),
          ),
        ),
        if (query.text.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            _inputHint(preview),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6C7080), fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('v13-check-button'),
                onPressed: () => _submit(),
                style: FilledButton.styleFrom(backgroundColor: _v13Ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t('FLIP PRÜFEN', 'CHECK FLIP')),
              ),
            ),
            const SizedBox(width: 9),
            OutlinedButton.icon(onPressed: widget.onScan, icon: const Icon(Icons.qr_code_scanner_rounded, size: 19), label: Text(t('Barcode', 'Barcode'))),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(t('Schnell wiederholen', 'Quick repeat'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestions.map((e) => ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: Text(e, overflow: TextOverflow.ellipsis)),
                  onPressed: () => _submit(e),
                )).toList(),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EF))),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, color: _v13Primary),
              const SizedBox(width: 10),
              Expanded(child: Text(t('Ziel: in wenigen Sekunden wissen, ob und bis wohin du kaufen solltest.', 'Goal: know within seconds whether to buy and your maximum price.'), style: const TextStyle(fontSize: 12.3, fontWeight: FontWeight.w800, color: Color(0xFF555968)))),
            ],
          ),
        ),
        if (widget.openFlips > 0) ...[
          const SizedBox(height: 13),
          Text(t('${widget.openFlips} offene Flips warten auf Verkauf.', '${widget.openFlips} open flips are waiting to sell.'), style: const TextStyle(fontSize: 12, color: Color(0xFF777B88))),
        ],
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 26),
          V13BannerAd(monetization: widget.monetization),
        ],
      ],
    );
  }

  String _inputHint(V13SearchInput input) {
    switch (input.kind) {
      case V13InputKind.url:
        return t('Link erkannt → FlipRadar sucht nach „${input.query}“', 'Link detected → searching for “${input.query}”');
      case V13InputKind.ean:
        return t('EAN erkannt', 'EAN detected');
      case V13InputKind.asin:
        return t('ASIN erkannt', 'ASIN detected');
      case V13InputKind.text:
        if (input.correction != null) return t('Schreibweise erkannt → ${input.query}', 'Spelling normalized → ${input.query}');
        return t('Direkte Produktsuche', 'Direct product search');
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }
}

enum V13Decision { waiting, buy, negotiate, skip }

class V13CheckPage extends StatefulWidget {
  final bool english;
  final V13SearchInput input;
  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<PriceSource> sources;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;

  const V13CheckPage({
    super.key,
    required this.english,
    required this.input,
    required this.targetRoi,
    required this.minProfit,
    required this.plan,
    required this.taxMode,
    required this.sources,
    required this.flips,
    required this.monetization,
    required this.onHistory,
    required this.onAddFlip,
  });

  @override
  State<V13CheckPage> createState() => _V13CheckPageState();
}

class _V13CheckPageState extends State<V13CheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final costs = TextEditingController(text: '0');
  final manualSell = TextEditingController();
  final buyFocus = FocusNode();
  final manualFocus = FocusNode();
  List<SourceListing> listings = [];
  final Set<String> pending = {};
  bool manualMode = false;
  double? manualCommitted;
  bool deepUnlocked = false;
  bool deepLoading = false;
  bool savedBought = false;
  int token = 0;
  V13Decision? lastHaptic;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.input.query);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  Future<void> _search() async {
    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final myToken = ++token;
    widget.onHistory(q);
    setState(() {
      listings = [];
      pending.clear();
      manualCommitted = null;
      manualSell.clear();
      manualMode = false;
      savedBought = false;
    });
    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    pending.addAll(direct.map((e) => e.id));
    if (mounted) setState(() {});
    if (direct.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());
      return;
    }
    for (final source in direct) {
      unawaited(_fetchOne(source, q, myToken));
    }
  }

  Future<void> _fetchOne(PriceSource source, String q, int myToken) async {
    List<SourceListing> result = [];
    try {
      result = await SourceRegistry.fetch(source, q);
    } catch (_) {}
    if (!mounted || myToken != token) return;
    final combined = [...listings, ...result];
    final dedupe = <String, SourceListing>{};
    for (final item in combined) {
      if (!item.total.isFinite || item.total <= 0) continue;
      final key = item.url.trim().isNotEmpty
          ? '${item.sourceId}|${item.url}'
          : '${item.sourceId}|${item.title.toLowerCase()}|${item.total.toStringAsFixed(2)}';
      dedupe[key] = item;
    }
    pending.remove(source.id);
    setState(() => listings = dedupe.values.toList()..sort((a, b) => a.total.compareTo(b.total)));
    if (pending.isEmpty && expectedSale == null) setState(() => manualMode = true);
    if (buy.text.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());
  }

  List<double> _valuesFor(Set<String> roles) => listings
      .where((e) => roles.contains(e.role))
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
    final med = _median(values)!;
    final filtered = values.where((v) => v >= med * .60 && v <= med * 1.60).toList();
    return filtered.length >= 3 ? filtered : values;
  }

  double? get activeMedian => _median(_clean(_valuesFor({'resale', 'local'})));
  double? get retailMedian => _median(_clean(_valuesFor({'retail', 'refurb'})));
  double? get buybackMedian => _median(_clean(_valuesFor({'buyback'})));
  String get category => v13Category(query.text);
  V13PersonalStats get personal => V13PersonalStats.forCategory(widget.flips, category);

  double? get baseExpectedSale {
    if (manualCommitted != null && manualCommitted! > 0) return manualCommitted;
    final median = activeMedian;
    if (median == null || median <= 0) return null;
    // Asking-price heuristic only; deliberately not labelled as sold data.
    return median * .90;
  }

  double? get expectedSale {
    final base = baseExpectedSale;
    if (base == null) return null;
    if (widget.plan != UserPlan.free && personal.sample >= 3 && personal.saleFactor != null) {
      return base * personal.saleFactor!;
    }
    return base;
  }

  double get extraCosts => v13Money(costs.text);
  double get buyPrice => v13Money(buy.text);

  double? get maxBuy {
    final sell = expectedSale;
    if (sell == null || sell <= 0) return null;
    final byRoi = (sell - extraCosts) / (1 + widget.targetRoi / 100);
    final byProfit = sell - extraCosts - widget.minProfit;
    return math.max(0, math.min(byRoi, byProfit));
  }

  double get profit {
    final sell = expectedSale ?? 0;
    return sell - buyPrice - extraCosts;
  }

  double get roi => buyPrice <= 0 ? 0 : profit / buyPrice * 100;

  V13Decision get decision {
    final limit = maxBuy;
    if (limit == null || buyPrice <= 0) return V13Decision.waiting;
    if (buyPrice <= limit) return V13Decision.buy;
    if (buyPrice <= limit * 1.12) return V13Decision.negotiate;
    return V13Decision.skip;
  }

  String get confidence {
    final values = _clean(_valuesFor({'resale', 'local'}));
    if (values.length < 3) return t('Niedrig', 'Low');
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final med = _median(values) ?? 1;
    final spread = (maxV - minV) / med;
    if (values.length >= 10 && spread < .35) return t('Hoch', 'High');
    if (values.length >= 5 && spread < .65) return t('Mittel', 'Medium');
    return t('Niedrig', 'Low');
  }

  List<double> get resaleValues => _clean(_valuesFor({'resale', 'local'}));

  double? get conservativeExit {
    final values = resaleValues;
    if (values.isEmpty) return buybackMedian;
    final idx = ((values.length - 1) * .25).floor();
    final lower = values[idx] * .85;
    final buyback = buybackMedian;
    if (buyback != null && buyback > 0) return math.max(lower, buyback);
    return lower;
  }

  double? _sourceMedian(String id) => _median(_clean(listings.where((e) => e.sourceId == id).map((e) => e.total).where((e) => e > 0).toList()));

  List<PriceSource> get visibleSources {
    final input = widget.sources.where((s) => s.enabled).toList();
    final q = query.text.toLowerCase();
    final fashion = RegExp(r'(nike|adidas|jordan|yeezy|sneaker|schuh|jacke|hose|kleid|tasche)').hasMatch(q);
    final electronics = RegExp(r'(iphone|samsung|galaxy|pixel|macbook|laptop|playstation|ps5|xbox|switch|kamera)').hasMatch(q);
    final order = fashion
        ? ['vinted', 'kleinanzeigen', 'ebay_de', 'idealo', 'geizhals', 'amazon_de', 'rebuy', 'backmarket', 'mediamarkt', 'saturn']
        : electronics
            ? ['ebay_de', 'kleinanzeigen', 'rebuy', 'backmarket', 'geizhals', 'idealo', 'amazon_de', 'mediamarkt', 'saturn', 'vinted']
            : ['ebay_de', 'kleinanzeigen', 'vinted', 'idealo', 'geizhals', 'amazon_de', 'rebuy', 'backmarket', 'mediamarkt', 'saturn'];
    final rank = <String, int>{for (var i = 0; i < order.length; i++) order[i]: i};
    input.sort((a, b) => (rank[a.id] ?? 99).compareTo(rank[b.id] ?? 99));
    return input;
  }

  @override
  Widget build(BuildContext context) {
    final d = decision;
    if (d != V13Decision.waiting && d != lastHaptic) {
      lastHaptic = d;
      WidgetsBinding.instance.addPostFrameCallback((_) => HapticFeedback.selectionClick());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Flip prüfen', 'Check flip'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _search, icon: const Icon(Icons.refresh_rounded), tooltip: t('Neu laden', 'Refresh'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(labelText: t('Artikel', 'Item'), prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded))),
          ),
          const SizedBox(height: 10),
          _V13MarketStrip(
            english: widget.english,
            expectedSale: expectedSale,
            activeMedian: activeMedian,
            count: resaleValues.length,
            confidence: confidence,
            pending: pending.length,
            personal: personal,
            isPro: widget.plan != UserPlan.free,
          ),
          const SizedBox(height: 10),
          _V13SourceScroller(
            english: widget.english,
            sources: visibleSources,
            priceFor: _sourceMedian,
            onOpen: _openSource,
            onEbaySold: _openEbaySold,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('v13-buy-input'),
            controller: buy,
            focusNode: buyFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('Was sollst du zahlen?', 'What would you pay?'), hintText: '0,00', suffixText: '€', prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded)),
          ),
          if (expectedSale == null || manualMode) ...[
            const SizedBox(height: 9),
            TextField(
              key: const ValueKey('v13-manual-sale-input'),
              controller: manualSell,
              focusNode: manualFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitManual(),
              decoration: InputDecoration(
                labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                hintText: t('vollständig eingeben', 'enter full amount'),
                suffixText: '€',
                suffixIcon: IconButton(onPressed: _commitManual, icon: const Icon(Icons.check_rounded)),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => setState(() => manualMode = true), icon: const Icon(Icons.edit_outlined, size: 17), label: Text(t('Verkaufspreis ändern', 'Change sale price'))),
            ),
          ],
          const SizedBox(height: 8),
          _V13DecisionCard(
            english: widget.english,
            decision: d,
            maxBuy: maxBuy,
            expectedSale: expectedSale,
            profit: profit,
            roi: roi,
            speed: personal.speedLabel(widget.english),
            confidence: confidence,
            minProfit: widget.minProfit,
            targetRoi: widget.targetRoi,
            onBought: d == V13Decision.waiting || savedBought ? null : _bought,
            onNegotiate: d == V13Decision.negotiate ? _copyOffer : null,
          ),
          if (expectedSale != null) ...[
            const SizedBox(height: 10),
            _V13DeepCheck(
              english: widget.english,
              unlocked: widget.plan != UserPlan.free || deepUnlocked,
              loading: deepLoading,
              conservativeExit: conservativeExit,
              buyback: buybackMedian,
              activeMedian: activeMedian,
              retail: retailMedian,
              personal: personal,
              category: category,
              taxMode: widget.taxMode,
              onReward: _rewardDeep,
              onPro: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: widget.english, monetization: widget.monetization))),
            ),
          ],
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(t('Kosten & Berechnung', 'Costs & calculation'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(t('Nur wenn du genauer rechnen willst', 'Only when you want more detail'), style: const TextStyle(fontSize: 11.5)),
            children: [
              TextField(controller: costs, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Zusatzkosten gesamt', 'Extra costs total'), suffixText: '€')),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text(t('Ziel: ${widget.targetRoi.toStringAsFixed(0)} % ROI + mindestens ${v13Euro(widget.minProfit)} Gewinn.', 'Target: ${widget.targetRoi.toStringAsFixed(0)}% ROI + at least ${v13Euro(widget.minProfit)} profit.'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF707483)))),
            ],
          ),
          if (widget.plan == UserPlan.free) ...[
            const SizedBox(height: 18),
            V13BannerAd(monetization: widget.monetization),
          ],
        ],
      ),
    );
  }

  void _commitManual() {
    final value = v13Money(manualSell.text);
    if (value <= 0) return;
    setState(() {
      manualCommitted = value;
      manualMode = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _openSource(PriceSource source) async {
    final uri = Uri.tryParse(source.searchUrl(query.text.trim()));
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEbaySold() async {
    final uri = Uri.parse('https://www.ebay.de/sch/i.html?_nkw=${Uri.encodeQueryComponent(query.text.trim())}&LH_Sold=1&LH_Complete=1');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _bought() {
    final expected = expectedSale;
    if (buyPrice <= 0 || expected == null) return;
    widget.onAddFlip(V13Flip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: query.text.trim(),
      category: category,
      buy: buyPrice,
      expectedAtBuy: expected,
      costs: extraCosts,
      sourceCount: resaleValues.length,
      confidence: confidence,
      status: 'Bought',
      createdAt: DateTime.now(),
    ));
    setState(() => savedBought = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Als gekauft gespeichert.', 'Saved as bought.'))));
  }

  void _copyOffer() {
    final limit = maxBuy ?? 0;
    final offer = math.max(0.0, math.min(limit * .95, buyPrice * .90)).toDouble();
    final message = t('Hallo, wären ${v13Euro(offer)} bei schneller Abwicklung für dich okay?', 'Hi, would ${v13Euro(offer)} work for a quick deal?');
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Verhandlungstext kopiert.', 'Negotiation message copied.'))));
  }

  Future<void> _rewardDeep() async {
    setState(() => deepLoading = true);
    final ok = await widget.monetization.rewardedUnlock();
    if (!mounted) return;
    setState(() {
      deepLoading = false;
      if (ok) deepUnlocked = true;
    });
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Werbung momentan nicht verfügbar.', 'Ad currently unavailable.'))));
  }

  @override
  void dispose() {
    query.dispose();
    buy.dispose();
    costs.dispose();
    manualSell.dispose();
    buyFocus.dispose();
    manualFocus.dispose();
    super.dispose();
  }
}

class _V13MarketStrip extends StatelessWidget {
  final bool english;
  final double? expectedSale;
  final double? activeMedian;
  final int count;
  final String confidence;
  final int pending;
  final V13PersonalStats personal;
  final bool isPro;

  const _V13MarketStrip({required this.english, required this.expectedSale, required this.activeMedian, required this.count, required this.confidence, required this.pending, required this.personal, required this.isPro});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: _v13Ink, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(t('FLIP-DATEN', 'FLIP DATA'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              const Spacer(),
              if (pending > 0) ...[
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 5),
                Text('$pending', style: const TextStyle(color: Color(0xFFC8CADB), fontSize: 10)),
              ] else
                Text(t('Qualität $confidence', 'Quality $confidence'), style: const TextStyle(color: Color(0xFFC8CADB), fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _V13Metric(label: t('PLANVERKAUF', 'SALE PLAN'), value: expectedSale == null ? '—' : v13Euro(expectedSale!), strong: true)),
              const SizedBox(width: 7),
              Expanded(child: _V13Metric(label: t('AKTIVE COMPS', 'ACTIVE COMPS'), value: '$count')),
              const SizedBox(width: 7),
              Expanded(child: _V13Metric(label: t('MEDIAN ANGEBOT', 'ASK MEDIAN'), value: activeMedian == null ? '—' : v13Euro(activeMedian!))),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            activeMedian == null
                ? t('Noch keine internen Wiederverkaufsdaten. Quellen unten direkt öffnen oder Verkaufspreis selbst setzen.', 'No internal resale data yet. Open a source below or set the sale price yourself.')
                : t('Planwert aus aktuellen Angeboten – keine automatisch behaupteten Sold-Daten.', 'Plan value from active listings – not claimed as sold data.'),
            style: const TextStyle(color: Color(0xFFBFC1D1), fontSize: 10.5),
          ),
          if (isPro && personal.sample >= 3) ...[
            const SizedBox(height: 4),
            Text(t('Persönlich angepasst mit ${personal.sample} eigenen Verkäufen.', 'Personalized using ${personal.sample} of your own sales.'), style: const TextStyle(color: Color(0xFF9FDAC9), fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _V13Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _V13Metric({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAEB0C5), fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: strong ? 15 : 13, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _V13SourceScroller extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final double? Function(String) priceFor;
  final ValueChanged<PriceSource> onOpen;
  final VoidCallback onEbaySold;

  const _V13SourceScroller({required this.english, required this.sources, required this.priceFor, required this.onOpen, required this.onEbaySold});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _V13SourceChip(name: 'eBay ${t('verkauft', 'sold')}', purpose: t('VERKAUFT', 'SOLD'), icon: Icons.history_rounded, color: const Color(0xFF3665F3), onTap: onEbaySold),
      ...sources.map((s) => _V13SourceChip(name: s.name, purpose: _purpose(s), icon: _sourceIcon(s.id), color: _sourceColor(s), price: priceFor(s.id), onTap: () => onOpen(s))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Direkt vergleichen', 'Compare now'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
        const SizedBox(height: 7),
        SizedBox(height: 62, child: ListView.separated(scrollDirection: Axis.horizontal, itemBuilder: (_, i) => items[i], separatorBuilder: (_, __) => const SizedBox(width: 7), itemCount: items.length)),
      ],
    );
  }

  String _purpose(PriceSource s) {
    if (s.id == 'idealo' || s.id == 'geizhals') return t('PREIS', 'PRICE');
    switch (s.role) {
      case 'resale': return t('ANGEBOTE', 'LISTINGS');
      case 'local': return t('LOKAL', 'LOCAL');
      case 'retail': return t('NEU', 'RETAIL');
      case 'buyback': return t('ANKAUF', 'BUYBACK');
      case 'refurb': return 'REFURB';
      default: return t('CHECK', 'CHECK');
    }
  }
}

class _V13SourceChip extends StatelessWidget {
  final String name;
  final String purpose;
  final IconData icon;
  final Color color;
  final double? price;
  final VoidCallback onTap;
  const _V13SourceChip({required this.name, required this.purpose, required this.icon, required this.color, required this.onTap, this.price});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            constraints: const BoxConstraints(minWidth: 116),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: .18))),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                Text(price == null ? purpose : '≈ ${v13Euro(price!)}', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
              ]),
            ]),
          ),
        ),
      );
}

class _V13DecisionCard extends StatelessWidget {
  final bool english;
  final V13Decision decision;
  final double? maxBuy;
  final double? expectedSale;
  final double profit;
  final double roi;
  final String speed;
  final String confidence;
  final double minProfit;
  final double targetRoi;
  final VoidCallback? onBought;
  final VoidCallback? onNegotiate;

  const _V13DecisionCard({required this.english, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onBought, this.onNegotiate});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    Color color;
    String title;
    IconData icon;
    switch (decision) {
      case V13Decision.buy:
        color = const Color(0xFF087F5B); title = t('KAUFEN', 'BUY'); icon = Icons.check_circle_rounded;
      case V13Decision.negotiate:
        color = const Color(0xFFC47B00); title = t('VERHANDELN', 'NEGOTIATE'); icon = Icons.handshake_rounded;
      case V13Decision.skip:
        color = const Color(0xFFC33A46); title = t('LASSEN', 'SKIP'); icon = Icons.cancel_rounded;
      case V13Decision.waiting:
        color = const Color(0xFF555A69); title = expectedSale == null ? t('VERKAUFSPREIS FEHLT', 'SALE PRICE NEEDED') : t('EINKAUFSPREIS EINGEBEN', 'ENTER BUY PRICE'); icon = Icons.arrow_upward_rounded;
    }
    return Container(
      key: const ValueKey('v13-decision-card'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withValues(alpha: .20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 25), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900))), if (maxBuy != null) Text('${t('MAX', 'MAX')} ${v13Euro(maxBuy!)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        if (decision != V13Decision.waiting && expectedSale != null) ...[
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: _V13LightMetric(label: t('GEWINN', 'PROFIT'), value: v13Euro(profit))),
            const SizedBox(width: 6),
            Expanded(child: _V13LightMetric(label: 'ROI', value: '${roi.toStringAsFixed(0)} %')),
            const SizedBox(width: 6),
            Expanded(child: _V13LightMetric(label: t('TEMPO', 'SPEED'), value: speed)),
          ]),
          const SizedBox(height: 7),
          Text(t('Ziel: ≥ ${targetRoi.toStringAsFixed(0)} % ROI und ≥ ${v13Euro(minProfit)} Gewinn · Datenqualität $confidence.', 'Target: ≥ ${targetRoi.toStringAsFixed(0)}% ROI and ≥ ${v13Euro(minProfit)} profit · data quality $confidence.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF686C79))),
          const SizedBox(height: 10),
          Row(children: [
            if (onBought != null) Expanded(child: FilledButton.icon(onPressed: onBought, icon: const Icon(Icons.inventory_2_rounded), label: Text(t('GEKAUFT', 'BOUGHT')))),
            if (onBought != null && onNegotiate != null) const SizedBox(width: 7),
            if (onNegotiate != null) Expanded(child: OutlinedButton.icon(onPressed: onNegotiate, icon: const Icon(Icons.copy_rounded, size: 18), label: Text(t('PREISVORSCHLAG', 'OFFER')))),
          ]),
        ] else ...[
          const SizedBox(height: 5),
          Text(expectedSale == null ? t('Quelle antippen oder erwarteten Verkaufspreis eingeben.', 'Tap a source or enter an expected sale price.') : t('Oben deinen Einkaufspreis eingeben.', 'Enter your buy price above.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF666A77))),
        ],
      ]),
    );
  }
}

class _V13LightMetric extends StatelessWidget {
  final String label;
  final String value;
  const _V13LightMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF787C89), fontWeight: FontWeight.w800)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))]),
      );
}

class _V13DeepCheck extends StatelessWidget {
  final bool english;
  final bool unlocked;
  final bool loading;
  final double? conservativeExit;
  final double? buyback;
  final double? activeMedian;
  final double? retail;
  final V13PersonalStats personal;
  final String category;
  final V13TaxMode taxMode;
  final VoidCallback onReward;
  final VoidCallback onPro;

  const _V13DeepCheck({required this.english, required this.unlocked, required this.loading, required this.conservativeExit, required this.buyback, required this.activeMedian, required this.retail, required this.personal, required this.category, required this.taxMode, required this.onReward, required this.onPro});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2B2A54), Color(0xFF5556D7)]), borderRadius: BorderRadius.circular(21)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, color: Colors.white), const SizedBox(width: 8), Text('DEEP CHECK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const Spacer(), const _V13Pill(text: 'PRO', foreground: _v13Primary, background: Colors.white)]),
          const SizedBox(height: 5),
          Text(t('Konservativer Exit · Kapitaltempo · persönliches Muster · Risiko', 'Conservative exit · capital speed · personal pattern · risk'), style: const TextStyle(color: Color(0xFFD4D5EE), fontSize: 11.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF))), onPressed: loading ? null : onReward, icon: loading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ondemand_video_rounded, size: 18), label: Text(t('WERBUNG SPÄTER', 'ADS LATER')))),
            const SizedBox(width: 7),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _v13Primary), onPressed: onPro, child: const Text('PRO'))),
          ]),
        ]),
      );
    }

    final tips = _riskTips(category, english);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE4E6EE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.auto_awesome_rounded, color: _v13Primary, size: 20), const SizedBox(width: 7), const Text('DEEP CHECK', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(personal.sample >= 2 ? '${personal.sample} ${t('eigene Sales', 'own sales')}' : t('Marktbasis', 'Market basis'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF777B88)))]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _V13MiniInfo(label: t('KONSERVATIV', 'CONSERVATIVE'), value: conservativeExit == null ? '—' : v13Euro(conservativeExit!))),
          const SizedBox(width: 6),
          Expanded(child: _V13MiniInfo(label: t('SOFORT-EXIT', 'FAST EXIT'), value: buyback == null ? '—' : v13Euro(buyback!))),
          const SizedBox(width: 6),
          Expanded(child: _V13MiniInfo(label: t('KAPITALTEMPO', 'CAPITAL SPEED'), value: personal.speedLabel(english))),
        ]),
        if (retail != null || activeMedian != null) ...[
          const SizedBox(height: 8),
          Text(t('Gebrauchtmarkt steht bewusst vor Neupreis. ${retail == null ? '' : 'Neupreis-Referenz ${v13Euro(retail!)}.'}', 'Resale market is intentionally prioritized over retail. ${retail == null ? '' : 'Retail reference ${v13Euro(retail!)}.'}'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7380))),
        ],
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: tips.map((e) => _V13Pill(text: e, foreground: const Color(0xFF515562), background: const Color(0xFFF0F1F6))).toList()),
        const SizedBox(height: 8),
        Text(t('Steuerprofil: ${v13TaxLabel(taxMode, false)} · Steuern werden nicht automatisch vom Gewinn abgezogen.', 'Tax profile: ${v13TaxLabel(taxMode, true)} · taxes are not automatically deducted from profit.'), style: const TextStyle(fontSize: 9.8, color: Color(0xFF858997))),
      ]),
    );
  }
}

class _V13MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _V13MiniInfo({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.8, color: Color(0xFF858997), fontWeight: FontWeight.w900)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))]));
}

List<String> _riskTips(String category, bool english) {
  final map = <String, List<String>>{
    'Smartphone': english ? ['Account lock', 'IMEI', 'Battery'] : ['Accountsperre', 'IMEI', 'Akku'],
    'Laptop': english ? ['Battery', 'Display', 'Charger'] : ['Akku', 'Display', 'Netzteil'],
    'Konsole': english ? ['Ban/account', 'Drive', 'Controller'] : ['Ban/Account', 'Laufwerk', 'Controller'],
    'Sneaker': english ? ['Authenticity', 'Size', 'Condition'] : ['Echtheit', 'Größe', 'Zustand'],
    'Kamera': english ? ['Shutter', 'Sensor', 'Lens'] : ['Auslösungen', 'Sensor', 'Objektiv'],
    'Werkzeug': english ? ['Battery', 'Serial', 'Wear'] : ['Akku', 'Seriennr.', 'Verschleiß'],
  };
  return map[category] ?? (english ? ['Variant', 'Condition', 'Completeness'] : ['Variante', 'Zustand', 'Vollständigkeit']);
}

class V13FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<V13Flip> onUpdate;
  final VoidCallback onPro;

  const V13FlipsPage({super.key, required this.english, required this.plan, required this.flips, required this.monetization, required this.onUpdate, required this.onPro});
  @override
  State<V13FlipsPage> createState() => _V13FlipsPageState();
}

class _V13FlipsPageState extends State<V13FlipsPage> {
  String filter = 'open';
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final open = widget.flips.where((e) => e.status != 'Sold').toList();
    final shown = filter == 'sold' ? sold : filter == 'all' ? widget.flips : open;
    final profit = sold.fold<double>(0, (a, b) => a + b.realizedProfit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final avgDays = days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Meine Flips', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(t('Gekauft → verkauft → daraus lernt FlipRadar.', 'Bought → sold → FlipRadar learns from it.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _v13Ink, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(child: _V13DarkStat(label: t('Gewinn', 'Profit'), value: v13Euro(profit))),
            Expanded(child: _V13DarkStat(label: t('Gebunden', 'Invested'), value: v13Euro(capital))),
            Expanded(child: _V13DarkStat(label: t('Ø Verkauf', 'Avg sell'), value: avgDays == null ? '—' : '${avgDays.toStringAsFixed(0)} T')),
          ]),
        ),
        if (sold.length >= 2) ...[
          const SizedBox(height: 10),
          _V13PersonalInsight(english: widget.english, sold: sold, pro: widget.plan != UserPlan.free, onPro: widget.onPro),
        ],
        const SizedBox(height: 13),
        SegmentedButton<String>(segments: [ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first)),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 38, color: _v13Primary), const SizedBox(height: 9), Text(t('Noch nichts hier', 'Nothing here yet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 3), Text(t('Beim Deal einmal auf „Gekauft“ tippen – der Rest wird übernommen.', 'Tap “Bought” once on a deal – the rest is filled automatically.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))) ]))
        else
          for (var i = 0; i < shown.length; i++) ...[
            _V13FlipCard(english: widget.english, flip: shown[i], onUpdate: widget.onUpdate),
            if (widget.plan == UserPlan.free && i == 2) ...[const SizedBox(height: 8), V13BannerAd(monetization: widget.monetization)],
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _V13DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _V13DarkStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFFB8BACC), fontSize: 9.5))]));
}

class _V13PersonalInsight extends StatelessWidget {
  final bool english;
  final List<V13Flip> sold;
  final bool pro;
  final VoidCallback onPro;
  const _V13PersonalInsight({required this.english, required this.sold, required this.pro, required this.onPro});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<V13Flip>>{};
    for (final f in sold) { byCategory.putIfAbsent(f.category, () => []).add(f); }
    final best = byCategory.entries.toList()..sort((a, b) => b.value.fold<double>(0, (x, y) => x + y.realizedRoi).compareTo(a.value.fold<double>(0, (x, y) => x + y.realizedRoi)));
    final bestName = best.isEmpty ? '—' : best.first.key;
    return Material(
      color: const Color(0xFFEDEDFC),
      borderRadius: BorderRadius.circular(19),
      child: ListTile(
        leading: const Icon(Icons.psychology_alt_rounded, color: _v13Primary),
        title: Text(t('Dein Flip-Muster', 'Your flip pattern'), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(pro ? t('Stärkste Kategorie bisher: $bestName · ${sold.length} echte Verkäufe fließen ein.', 'Strongest category so far: $bestName · ${sold.length} real sales are used.') : t('${sold.length} Verkäufe gesammelt · PRO nutzt sie für persönliche Empfehlungen.', '${sold.length} sales collected · PRO uses them for personal recommendations.'), style: const TextStyle(fontSize: 11.5)),
        trailing: pro ? const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B)) : TextButton(onPressed: onPro, child: const Text('PRO')),
      ),
    );
  }
}

class _V13FlipCard extends StatelessWidget {
  final bool english;
  final V13Flip flip;
  final ValueChanged<V13Flip> onUpdate;
  const _V13FlipCard({required this.english, required this.flip, required this.onUpdate});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flip.status == 'Sold';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9EAF0))),
      child: Column(children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: (sold ? const Color(0xFF087F5B) : _v13Primary).withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(sold ? Icons.check_rounded : Icons.inventory_2_outlined, color: sold ? const Color(0xFF087F5B) : _v13Primary)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(flip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${flip.category} · ${sold ? t('verkauft', 'sold') : flip.status == 'Listed' ? t('inseriert', 'listed') : t('gekauft', 'bought')}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B)))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(sold ? v13Euro(flip.realizedProfit) : v13Euro(flip.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sold && flip.realizedProfit >= 0 ? const Color(0xFF087F5B) : _v13Ink)), Text(sold ? '${flip.daysToSell ?? 0} ${t('Tage', 'days')}' : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B8E9A)))])
        ]),
        if (!sold) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (flip.status == 'Bought') Expanded(child: OutlinedButton(onPressed: () => onUpdate(flip.copyWith(status: 'Listed', listedAt: DateTime.now())), child: Text(t('Inseriert', 'Listed')))),
            if (flip.status == 'Bought') const SizedBox(width: 7),
            Expanded(child: FilledButton(onPressed: () => _soldDialog(context), child: Text(t('Verkauft', 'Sold')))),
          ]),
        ],
      ]),
    );
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

class V13SettingsPage extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<PriceSource> sources;
  final V13Monetization monetization;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<double> onRoi;
  final ValueChanged<double> onMinProfit;
  final ValueChanged<V13TaxMode> onTaxMode;
  final ValueChanged<String> onBackend;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<UserPlan> onPlanPreview;

  const V13SettingsPage({super.key, required this.english, required this.backend, required this.targetRoi, required this.minProfit, required this.plan, required this.taxMode, required this.sources, required this.monetization, required this.onLanguage, required this.onRoi, required this.onMinProfit, required this.onTaxMode, required this.onBackend, required this.onSources, required this.onPlanPreview});
  @override
  State<V13SettingsPage> createState() => _V13SettingsPageState();
}

class _V13SettingsPageState extends State<V13SettingsPage> {
  late double roi;
  late double minProfit;
  late bool english;
  String t(String de, String en) => english ? en : de;

  @override
  void initState() {
    super.initState();
    roi = widget.targetRoi;
    minProfit = widget.minProfit;
    english = widget.english;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Einstellungen', 'Settings'), style: const TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28), children: [
          _V13Section(title: t('Wann ist ein Flip gut?', 'When is a flip good?'), subtitle: t('Einmal einstellen – danach rechnet FlipRadar automatisch.', 'Set once – FlipRadar calculates automatically after that.')),
          const SizedBox(height: 9),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [
            Row(children: [Text(t('Mindest-ROI', 'Minimum ROI'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${roi.toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _v13Primary))]),
            Slider(value: roi, min: 10, max: 100, divisions: 18, onChanged: (v) => setState(() => roi = v), onChangeEnd: widget.onRoi),
            const Divider(),
            Row(children: [Text(t('Mindestgewinn', 'Minimum profit'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(v13Euro(minProfit), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _v13Primary))]),
            Slider(value: minProfit, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => minProfit = v), onChangeEnd: widget.onMinProfit),
          ])),
          const SizedBox(height: 18),
          _V13Section(title: 'FlipRadar PRO'),
          const SizedBox(height: 8),
          _V13ProCard(english: english, active: widget.plan != UserPlan.free, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: english, monetization: widget.monetization)))),
          const SizedBox(height: 18),
          _V13Section(title: t('Preisquellen', 'Price sources')),
          const SizedBox(height: 8),
          Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: ListTile(leading: const Icon(Icons.storefront_outlined, color: _v13Primary), title: Text(t('${widget.sources.where((e) => e.enabled).length} Quellen aktiv', '${widget.sources.where((e) => e.enabled).length} sources enabled'), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(t('Ein-/ausschalten', 'Enable/disable')), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13SourcesPage(english: english, sources: widget.sources, onChanged: widget.onSources))))),
          const SizedBox(height: 18),
          _V13Section(title: t('Kaufmännisch', 'Business')),
          const SizedBox(height: 8),
          DropdownButtonFormField<V13TaxMode>(initialValue: widget.taxMode, decoration: InputDecoration(labelText: t('Steuerprofil', 'Tax profile')), items: V13TaxMode.values.map((e) => DropdownMenuItem(value: e, child: Text(v13TaxLabel(e, english)))).toList(), onChanged: (v) { if (v != null) widget.onTaxMode(v); }),
          const SizedBox(height: 5),
          Text(t('Das Profil dient der Einordnung. FlipRadar zieht aktuell keine Steuer automatisch vom Gewinn ab.', 'The profile is contextual. FlipRadar does not currently deduct taxes automatically.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF7B7F8C))),
          const SizedBox(height: 18),
          _V13Section(title: t('Sprache & Datenschutz', 'Language & privacy')),
          const SizedBox(height: 8),
          SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Deutsch')), ButtonSegment(value: true, label: Text('English'))], selected: {english}, onSelectionChanged: (v) { setState(() => english = v.first); widget.onLanguage(v.first); }),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: widget.monetization.showPrivacyOptions, icon: const Icon(Icons.privacy_tip_outlined), label: Text(t('Werbe-Datenschutz verwalten', 'Manage ad privacy'))),
          const SizedBox(height: 15),
          ExpansionTile(tilePadding: EdgeInsets.zero, leading: const Icon(Icons.build_outlined), title: Text(t('Für Profis & Entwickler', 'For pros & developers'), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(t('Im Alltag nicht nötig', 'Not needed day to day'), style: const TextStyle(fontSize: 11.5)), children: [
            TextFormField(initialValue: widget.backend, decoration: InputDecoration(labelText: t('Eigener FlipRadar-Server', 'Custom FlipRadar server'), hintText: SourceRegistry.defaultBackend), onFieldSubmitted: widget.onBackend),
            const SizedBox(height: 9),
            Text(t('SAFE START: Werbung und Play-Käufe sind vorübergehend deaktiviert. Nach dem bestätigten App-Start werden sie einzeln wieder aktiviert.', 'SAFE START: ads and Play purchases are temporarily disabled. They will be re-enabled one at a time after startup is confirmed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF737786))),
            const SizedBox(height: 9),
            SegmentedButton<UserPlan>(segments: const [ButtonSegment(value: UserPlan.free, label: Text('FREE')), ButtonSegment(value: UserPlan.pro, label: Text('PRO TEST'))], selected: {widget.plan == UserPlan.free ? UserPlan.free : UserPlan.pro}, onSelectionChanged: (v) => widget.onPlanPreview(v.first)),
          ]),
        ]),
      );
}

class _V13Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _V13Section({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF777B88)))]]);
}

class _V13ProCard extends StatelessWidget {
  final bool english;
  final bool active;
  final VoidCallback onTap;
  const _V13ProCard({required this.english, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_v13Ink, Color(0xFF5657DB)]), borderRadius: BorderRadius.circular(21)), child: Row(children: [const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 29), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(active ? (english ? 'PRO active' : 'PRO aktiv') : 'FlipRadar PRO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)), Text(english ? 'No ads · Deep Check · personal learning' : 'Werbefrei · Deep Check · persönliches Lernen', style: const TextStyle(color: Color(0xFFD4D5EA), fontSize: 10.8))])), const Icon(Icons.chevron_right_rounded, color: Colors.white)]))),
      );
}

class V13SourcesPage extends StatefulWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;
  const V13SourcesPage({super.key, required this.english, required this.sources, required this.onChanged});
  @override
  State<V13SourcesPage> createState() => _V13SourcesPageState();
}

class _V13SourcesPageState extends State<V13SourcesPage> {
  late List<PriceSource> items;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28), children: [
          Text(t('Nur Quellen aktivieren, die du wirklich sehen willst.', 'Only enable sources you actually want to see.'), style: const TextStyle(fontSize: 12, color: Color(0xFF747885))),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 7), child: SwitchListTile(value: items[i].enabled, onChanged: (v) { setState(() => items[i] = items[i].copyWith(enabled: v)); widget.onChanged([...items]); }, tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), secondary: Icon(_sourceIcon(items[i].id), color: _sourceColor(items[i])), title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(_role(items[i]), style: const TextStyle(fontSize: 10.5)))),
        ]),
      );
  String _role(PriceSource s) { switch (s.role) { case 'resale': return t('Wiederverkauf', 'Resale'); case 'local': return t('Lokal/Secondhand', 'Local/secondhand'); case 'retail': return t('Neupreis', 'Retail'); case 'buyback': return t('Sofort-Ankauf', 'Buyback'); case 'refurb': return 'Refurbished'; default: return t('Referenz', 'Reference'); } }
}

class V13Paywall extends StatefulWidget {
  final bool english;
  final V13Monetization monetization;
  const V13Paywall({super.key, required this.english, required this.monetization});
  @override
  State<V13Paywall> createState() => _V13PaywallState();
}

class _V13PaywallState extends State<V13Paywall> {
  String t(String de, String en) => widget.english ? en : de;
  @override
  void initState() { super.initState(); widget.monetization.addListener(_refresh); }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final month = widget.monetization.product(V13Monetization.monthlyId);
    final year = widget.monetization.product(V13Monetization.yearlyId);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
        const Icon(Icons.workspace_premium_rounded, size: 48, color: _v13Primary),
        const SizedBox(height: 10),
        Text('FlipRadar PRO', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
        const SizedBox(height: 6),
        Text(t('Mehr Sicherheit, weniger Handarbeit – ohne Werbung.', 'More confidence, less manual work – without ads.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF707483))),
        const SizedBox(height: 20),
        for (final item in [t('Deep Check mit konservativem Exit & Risiko', 'Deep Check with conservative exit & risk'), t('Persönliche Empfehlungen aus deinen echten Verkäufen', 'Personal recommendations from your real sales'), t('Kapitaltempo & bessere Verkaufsanalyse', 'Capital speed & better sale analysis'), t('Keine Werbebanner', 'No ad banners')]) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B), size: 20), const SizedBox(width: 8), Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)))])),
        const SizedBox(height: 15),
        _V13PlanChoice(title: t('Jährlich', 'Yearly'), price: year?.price ?? '59,99 € / Jahr', badge: t('BESTER WERT', 'BEST VALUE'), enabled: year != null, onTap: year == null ? null : () => widget.monetization.buy(year)),
        const SizedBox(height: 8),
        _V13PlanChoice(title: t('Monatlich', 'Monthly'), price: month?.price ?? '7,99 € / Monat', enabled: month != null, onTap: month == null ? null : () => widget.monetization.buy(month)),
        const SizedBox(height: 10),
        if (!widget.monetization.billingAvailable || (month == null && year == null))
          Text(t('SAFE START: PRO-Käufe sind in dieser Testversion absichtlich deaktiviert. Die Oberfläche bleibt vorbereitet.', 'SAFE START: PRO purchases are intentionally disabled in this test build. The UI remains prepared.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B))),
        TextButton(onPressed: widget.monetization.restore, child: Text(t('Käufe wiederherstellen', 'Restore purchases'))),
        const SizedBox(height: 6),
        Text(t('Vor produktivem Start werden Käufe serverseitig verifiziert.', 'Purchases will be server-verified before production launch.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Color(0xFF8A8E9B))),
      ]),
    );
  }
  @override
  void dispose() { widget.monetization.removeListener(_refresh); super.dispose(); }
}

class _V13PlanChoice extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool enabled;
  final VoidCallback? onTap;
  const _V13PlanChoice({required this.title, required this.price, required this.enabled, this.badge, this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: enabled ? Colors.white : const Color(0xFFF0F1F4), borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: enabled ? const Color(0xFFDADCE8) : const Color(0xFFE2E3E8)), borderRadius: BorderRadius.circular(18)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), if (badge != null) ...[const SizedBox(width: 6), _V13Pill(text: badge!, foreground: const Color(0xFF087F5B), background: const Color(0xFFE1F5EE))]]), const SizedBox(height: 2), Text(price, style: const TextStyle(color: Color(0xFF656978), fontSize: 12))])), Icon(enabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded)]))));
}

class V13BannerAd extends StatelessWidget {
  final V13Monetization monetization;
  const V13BannerAd({super.key, required this.monetization});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _V13Pill extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;
  const _V13Pill({required this.text, required this.foreground, required this.background});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)), child: Text(text, style: TextStyle(color: foreground, fontSize: 8.5, fontWeight: FontWeight.w900)));
}

Color _sourceColor(PriceSource source) {
  final hex = int.tryParse('FF${source.colorHex}', radix: 16);
  return Color(hex ?? 0xFF5146E5);
}

IconData _sourceIcon(String id) {
  switch (id) {
    case 'ebay_de': return Icons.sell_outlined;
    case 'kleinanzeigen': return Icons.location_on_outlined;
    case 'vinted': return Icons.checkroom_outlined;
    case 'amazon_de': return Icons.shopping_bag_outlined;
    case 'mediamarkt': return Icons.devices_other_outlined;
    case 'saturn': return Icons.laptop_chromebook_outlined;
    case 'idealo': return Icons.compare_arrows_rounded;
    case 'geizhals': return Icons.price_check_rounded;
    case 'rebuy': return Icons.recycling_rounded;
    case 'backmarket': return Icons.autorenew_rounded;
    default: return Icons.open_in_new_rounded;
  }
}
