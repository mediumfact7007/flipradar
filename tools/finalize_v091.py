from pathlib import Path
import re


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"Missing expected snippet: {label}")
    return text.replace(old, new, 1)


# ---------- Active V0.9 app ----------
p = Path("lib/v09_app.dart")
s = p.read_text()
s = replace_once(
    s,
    "final safe = v.isFinite ? v.clamp(10, 100).toDouble() : 35;",
    "final safe = v.isFinite ? v.clamp(10, 100).toDouble() : 35.0;",
    "ROI fallback",
)

if "String extractSharedQuery(String raw)" not in s:
    helper = r'''
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
      .replaceAll(RegExp(r'\b\d[\d.\s]*(?:,\d{1,2})?\s*€\b'), ' ')
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
'''
    s = replace_once(
        s,
        "\nclass FlipRadarFinalApp",
        helper + "\nclass FlipRadarFinalApp",
        "shared helper insertion",
    )

if "String? _pendingSharedQuery;" not in s:
    s = replace_once(
        s,
        "  DateTime? _lastSharedAt;\n",
        "  DateTime? _lastSharedAt;\n  String? _pendingSharedQuery;\n",
        "pending share field",
    )

s = replace_once(
    s,
    "    _lastSharedQuery = q;\n    _lastSharedAt = now;\n    Future.microtask(() => openCheck(q));",
    "    _lastSharedQuery = q;\n"
    "    _lastSharedAt = now;\n"
    "    _pendingSharedQuery = q;\n"
    "    Future.microtask(_drainSharedQuery);",
    "share dispatch",
)

pattern = re.compile(
    r"  String _queryFromShared\(String raw\) \{.*?\n  \}\n\n  String _limitQuery",
    re.S,
)
replacement = '''  String _queryFromShared(String raw) => _limitQuery(extractSharedQuery(raw));

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

  String _limitQuery'''
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not replace shared-query parser")

s = replace_once(
    s,
    "    } finally {\n      _openingCheck = false;\n      if (mounted) setState(() {});\n    }",
    "    } finally {\n"
    "      _openingCheck = false;\n"
    "      final hasPendingShare = _pendingSharedQuery != null;\n"
    "      if (mounted) setState(() {});\n"
    "      if (mounted && hasPendingShare) {\n"
    "        WidgetsBinding.instance.addPostFrameCallback((_) => _drainSharedQuery());\n"
    "      }\n"
    "    }",
    "pending share after route",
)

s = s.replace(
    "          NavigationDestination(\n"
    "            icon: const Icon(Icons.inventory_2_outlined),\n"
    "            selectedIcon: const Icon(Icons.inventory_2),\n"
    "            label: 'Flips',\n"
    "          ),",
    "          const NavigationDestination(\n"
    "            icon: Icon(Icons.inventory_2_outlined),\n"
    "            selectedIcon: Icon(Icons.inventory_2),\n"
    "            label: 'Flips',\n"
    "          ),",
    1,
)
p.write_text(s)


# ---------- Shared legacy UI still used by V0.9 ----------
p = Path("lib/v07.dart")
s = p.read_text()
s = s.replace(
    "          NavigationDestination(\n"
    "            icon: const Icon(Icons.inventory_2_outlined),\n"
    "            selectedIcon: const Icon(Icons.inventory_2),\n"
    "            label: 'Flips',\n"
    "          ),",
    "          const NavigationDestination(\n"
    "            icon: Icon(Icons.inventory_2_outlined),\n"
    "            selectedIcon: Icon(Icons.inventory_2),\n"
    "            label: 'Flips',\n"
    "          ),",
    1,
)
p.write_text(s)

p = Path("lib/v07_check.dart")
s = p.read_text().replace(
    "              decoration: InputDecoration(\n"
    "                hintText: '0,00',\n"
    "                suffixText: '€',\n"
    "                prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded),\n"
    "              ),",
    "              decoration: const InputDecoration(\n"
    "                hintText: '0,00',\n"
    "                suffixText: '€',\n"
    "                prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),\n"
    "              ),",
    1,
)
p.write_text(s)

p = Path("lib/v07_library.dart")
s = p.read_text()
s = replace_once(
    s,
    "final capital = open.fold<double>(0, (a, b) => a + b.buy);",
    "final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);",
    "invested capital includes costs",
)
s = replace_once(
    s,
    "              final parsed = double.tryParse(controller.text.replaceAll(',', '.'));\n"
    "              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);",
    "              final parsed = _parseLibraryMoney(controller.text);\n"
    "              if (parsed > 0) Navigator.pop(context, parsed);",
    "sale dialog parser",
)
if "double _parseLibraryMoney(String raw)" not in s:
    s += r'''

double _parseLibraryMoney(String raw) {
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
'''
p.write_text(s)


# ---------- Source adapter robustness ----------
p = Path("lib/source_registry.dart")
s = p.read_text()
s = replace_once(
    s,
    "      live: json['live'] as bool? ?? true,",
    "      live: json['live'] is bool ? json['live'] as bool : true,",
    "safe live parsing",
)
old = '''  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }'''
new = r'''  static double _toDouble(dynamic value) {
    if (value is num) return value.isFinite ? value.toDouble() : 0;
    var raw = value?.toString().trim() ?? '';
    raw = raw
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (raw.isEmpty) return 0;
    final comma = raw.lastIndexOf(',');
    final dot = raw.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      raw = comma > dot
          ? raw.replaceAll('.', '').replaceAll(',', '.')
          : raw.replaceAll(',', '');
    } else if (comma >= 0) {
      final decimals = raw.length - comma - 1;
      raw = decimals == 3 && comma > 0
          ? raw.replaceAll(',', '')
          : raw.replaceAll(',', '.');
    } else if (dot >= 0) {
      final decimals = raw.length - dot - 1;
      if (decimals == 3 && dot > 0) raw = raw.replaceAll('.', '');
    }
    final parsed = double.tryParse(raw);
    return parsed == null || !parsed.isFinite ? 0 : parsed;
  }'''
s = replace_once(s, old, new, "localized adapter number parser")
manifest_decode = "    final decoded = jsonDecode(response.body);\n    if (decoded is! Map<String, dynamic>) {"
s = replace_once(
    s,
    manifest_decode,
    "    if (response.bodyBytes.length > 256 * 1024) {\n"
    "      throw const FormatException('Partner-Manifest ist zu groß.');\n"
    "    }\n"
    "    final decoded = jsonDecode(response.body);\n"
    "    if (decoded is! Map<String, dynamic>) {",
    "manifest size limit",
)
p.write_text(s)


# ---------- Backend correctness ----------
p = Path("server/index.js")
s = p.read_text()
s = replace_once(
    s,
    "url.searchParams.set('filter', 'conditions:{USED}');",
    "url.searchParams.set('filter', 'conditions:{USED},buyingOptions:{FIXED_PRICE}');",
    "eBay upstream fixed-price filter",
)
s = replace_once(
    s,
    "    if (offer.isShippable === false || offer.isPreorder === true) continue;\n\n    const csv = offer.offerCSV;",
    "    if (offer.isShippable === false || offer.isPreorder === true) continue;\n"
    "    // Amazon is a NEW-price reference in FlipRadar. Used/refurbished\n"
    "    // marketplace offers must not lower the retail benchmark.\n"
    "    if (Number(offer.condition) !== 1) continue;\n\n"
    "    const csv = offer.offerCSV;",
    "Keepa new condition filter",
)
s = s.replace("version: '0.9.0'", "version: '0.9.1'")
p.write_text(s)


# ---------- Version ----------
p = Path("pubspec.yaml")
s = p.read_text()
if "version: 0.9.0+9" in s:
    s = s.replace("version: 0.9.0+9", "version: 0.9.1+10", 1)
elif "version: 0.9.1+10" not in s:
    raise SystemExit("Unexpected pubspec version")
p.write_text(s)


# ---------- Main build workflow ----------
p = Path(".github/workflows/build-android-apk.yml")
s = p.read_text().replace("FlipRadar-V0.9-FINAL-APK", "FlipRadar-V0.9.1-FINAL-APK")
marker = "          grep -q '\"sources\"' /tmp/status.json\n"
if "unsupported_source" not in s:
    extra = '''          code=$(curl -sS -o /tmp/bad-source.json -w '%{http_code}' 'http://127.0.0.1:8099/v1/market/search?source=bad&q=test')
          test "$code" = "400"
          grep -q 'unsupported_source' /tmp/bad-source.json
'''
    s = replace_once(s, marker, marker + extra, "negative backend smoke test")
p.write_text(s)


# ---------- Tests ----------
Path("test/deal_flow_test.dart").write_text(r'''import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildCheck({double targetRoi = 35}) {
  return MaterialApp(
    home: FinalCheckPage(
      english: false,
      initialQuery: 'Testgerät 123',
      targetRoi: targetRoi,
      plan: UserPlan.free,
      sources: const [],
      onHistory: (_) {},
      onWatch: (_) {},
      onAddFlip: (_) {},
      onRemoveFlip: (_) {},
    ),
  );
}

Future<void> enterManualDeal(
  WidgetTester tester, {
  required String buy,
  required String sell,
}) async {
  await tester.pumpWidget(buildCheck());
  await tester.pumpAndSettle();

  expect(find.text('Noch keine automatischen Wiederverkaufsdaten'), findsOneWidget);
  final fields = find.byType(TextField);
  expect(fields.evaluate().length, greaterThanOrEqualTo(3));
  await tester.enterText(fields.at(1), buy);
  await tester.enterText(fields.at(2), sell);
  await tester.pump();
}

void main() {
  testWidgets('active final flow recommends buy at target ROI', (tester) async {
    await enterManualDeal(tester, buy: '100', sell: '200');
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('148 €'), findsOneWidget);
  });

  testWidgets('active final flow recommends a concrete negotiation', (tester) async {
    await enterManualDeal(tester, buy: '160', sell: '200');
    expect(find.text('VERHANDELN'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Versuch 140 €'), findsOneWidget);
  });

  testWidgets('German thousands input is accepted in active deal flow', (tester) async {
    await enterManualDeal(tester, buy: '1.000,00', sell: '2.000,00');
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.text('1.481 €'), findsOneWidget);
  });
}
''')

Path("test/source_registry_test.dart").write_text(r'''import 'package:flipradar/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('third-party source cannot influence automatic decision', () {
    final source = PriceSource.fromJson({
      'id': 'partner-shop',
      'name': 'Partner Shop',
      'search_url': 'https://partner.example/search?q={query}',
      'adapter_url': 'https://api.partner.example/search?q={query}',
      'role': 'resale',
      'color': 'ABCDEF',
    });
    expect(source.builtIn, isFalse);
    expect(source.trustedForDecision, isFalse);
    final listing = SourceListing.fromJson({
      'title': 'Manipulated result',
      'price': 9999,
      'shipping': 0,
      'live': true,
    }, source);
    expect(listing.role, 'reference');
  });

  test('private or insecure adapter URLs are rejected', () {
    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'http://127.0.0.1:8080/?q={query}',
      }),
      throwsFormatException,
    );
    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe LAN',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'https://192.168.1.5/?q={query}',
      }),
      throwsFormatException,
    );
  });

  test('localized adapter prices and non-bool live field are safe', () {
    const source = PriceSource(
      id: 'trusted-test',
      name: 'Trusted',
      subtitle: 'test',
      searchUrlTemplate: 'https://example.com/?q={query}',
      role: 'resale',
      trustedForDecision: true,
    );
    final listing = SourceListing.fromJson({
      'title': 'Item',
      'price': '1.299,99 €',
      'shipping': '4,99',
      'live': 'true',
    }, source);
    expect(listing.price, closeTo(1299.99, 0.001));
    expect(listing.shipping, closeTo(4.99, 0.001));
    expect(listing.total, closeTo(1304.98, 0.001));
    expect(listing.live, isTrue);
  });

  test('invalid color and role fall back safely', () {
    final source = PriceSource.fromJson({
      'name': 'Safe Source',
      'search_url': 'https://example.com/?q={query}',
      'role': 'super-trusted',
      'color': 'not-a-color',
    });
    expect(source.role, 'reference');
    expect(source.colorHex, '5146E5');
  });
}
''')

Path("test/widget_test.dart").write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipradar/main.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const <SharedMediaFile>[],
      mediaStream: const Stream<List<SharedMediaFile>>.empty(),
    );
  });

  test('money input supports German and English formats safely', () {
    expect(parseMoneyInput('1.299,99 €'), closeTo(1299.99, 0.001));
    expect(parseMoneyInput('1,299.99'), closeTo(1299.99, 0.001));
    expect(parseMoneyInput('49,90'), closeTo(49.90, 0.001));
    expect(parseMoneyInput('1.299'), closeTo(1299, 0.001));
    expect(parseMoneyInput('1.234.567,89'), closeTo(1234567.89, 0.001));
    expect(parseMoneyInput('-20'), 0);
    expect(parseMoneyInput('abc'), 0);
  });

  test('shared marketplace text extracts a useful product query', () {
    expect(
      extractSharedQuery(
        'Gerade bei #Kleinanzeigen gefunden. Wie findest du das?\n'
        'https://www.kleinanzeigen.de/s-anzeige/apple-iphone-15-pro-256gb/1234567890-173-1234',
      ),
      'apple iphone 15 pro 256gb',
    );
    expect(
      extractSharedQuery(
        'Apple iPhone 15 Pro 256GB 850 € https://www.ebay.de/itm/123456789',
      ),
      'Apple iPhone 15 Pro 256GB',
    );
    expect(
      extractSharedQuery('https://www.ebay.de/sch/i.html?_nkw=PlayStation+5+Slim'),
      'PlayStation 5 Slim',
    );
  });

  testWidgets('FlipRadar final starts with action-first home', (tester) async {
    await tester.pumpWidget(const FlipRadarFinalApp());
    await tester.pumpAndSettle();
    expect(find.text('FlipRadar'), findsOneWidget);
    expect(find.text('Lohnt sich der Deal?'), findsOneWidget);
    expect(find.text('BARCODE SCANNEN'), findsOneWidget);
  });

  testWidgets('changing the item clears an old manual deal decision', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FinalCheckPage(
          english: false,
          initialQuery: '',
          targetRoi: 35,
          plan: UserPlan.free,
          sources: const [],
          onHistory: (_) {},
          onWatch: (_) {},
          onAddFlip: (_) {},
          onRemoveFlip: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'iPhone 15');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine automatischen Wiederverkaufsdaten'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.enterText(find.byType(TextField).at(2), '200');
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'PlayStation 5');
    await tester.pump();
    expect(find.text('KAUFEN'), findsNothing);
    expect(find.text('Artikel suchen → Preis eingeben → Entscheidung.'), findsOneWidget);
  });
}
''')

Path("test/library_flow_test.dart").write_text(r'''import 'package:flipradar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sold dialog accepts German thousands format', (tester) async {
    FlipItem? updated;
    final item = FlipItem(
      id: '1',
      name: 'Testgerät',
      buy: 700,
      sell: 1200,
      costs: 25,
      status: 'Listed',
      source: 'Test',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlipsPage(
            english: false,
            plan: UserPlan.pro,
            flips: [item],
            onUpdate: (value) => updated = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Verkauft'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.299,99');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.status, 'Sold');
    expect(updated!.sell, closeTo(1299.99, 0.001));
  });
}
''')
