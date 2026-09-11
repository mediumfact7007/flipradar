import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SourceListing {
  final String sourceId;
  final String sourceName;
  final String role;
  final String title;
  final double price;
  final double shipping;
  final String url;
  final String condition;
  final bool live;

  const SourceListing({
    required this.sourceId,
    required this.sourceName,
    required this.role,
    required this.title,
    required this.price,
    required this.shipping,
    required this.url,
    required this.condition,
    required this.live,
  });

  double get total => price + shipping;

  factory SourceListing.fromJson(Map<String, dynamic> json, PriceSource source) {
    return SourceListing(
      sourceId: source.id,
      sourceName: source.name,
      role: source.role,
      title: json['title']?.toString() ?? 'Listing',
      price: _toDouble(json['price']),
      shipping: _toDouble(json['shipping']),
      url: json['url']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      live: json['live'] as bool? ?? true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }
}

class PriceSource {
  final String id;
  final String name;
  final String subtitle;
  final String searchUrlTemplate;
  final String? adapterUrlTemplate;
  final String role;
  final bool enabled;
  final bool builtIn;
  final bool recommended;
  final String colorHex;

  const PriceSource({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.searchUrlTemplate,
    this.adapterUrlTemplate,
    this.role = 'reference',
    this.enabled = true,
    this.builtIn = true,
    this.recommended = false,
    this.colorHex = '5146E5',
  });

  bool get canFetchInApp => (adapterUrlTemplate ?? '').trim().isNotEmpty;
  bool get isResaleMarket => role == 'resale' || role == 'local';
  bool get isRetailReference => role == 'retail' || role == 'refurb';
  bool get isBuyback => role == 'buyback';

  PriceSource copyWith({bool? enabled, String? adapterUrlTemplate}) {
    return PriceSource(
      id: id,
      name: name,
      subtitle: subtitle,
      searchUrlTemplate: searchUrlTemplate,
      adapterUrlTemplate: adapterUrlTemplate ?? this.adapterUrlTemplate,
      role: role,
      enabled: enabled ?? this.enabled,
      builtIn: builtIn,
      recommended: recommended,
      colorHex: colorHex,
    );
  }

  String searchUrl(String query) =>
      searchUrlTemplate.replaceAll('{query}', Uri.encodeQueryComponent(query));

  String? adapterUrl(String query) {
    final value = adapterUrlTemplate;
    if (value == null || value.trim().isEmpty) return null;
    return value.replaceAll('{query}', Uri.encodeQueryComponent(query));
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'search_url': searchUrlTemplate,
        'adapter_url': adapterUrlTemplate,
        'role': role,
        'enabled': enabled,
        'built_in': builtIn,
        'recommended': recommended,
        'color': colorHex,
      };

  factory PriceSource.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final search = json['search_url']?.toString().trim() ?? '';
    if (name.isEmpty || search.isEmpty || !search.contains('{query}')) {
      throw const FormatException('Source manifest needs name and search_url with {query}.');
    }
    final rawId = json['id']?.toString().trim();
    final generated = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return PriceSource(
      id: (rawId == null || rawId.isEmpty) ? generated : rawId,
      name: name,
      subtitle: json['subtitle']?.toString() ?? 'Eigene Quelle',
      searchUrlTemplate: search,
      adapterUrlTemplate: json['adapter_url']?.toString(),
      role: json['role']?.toString() ?? 'reference',
      enabled: json['enabled'] as bool? ?? true,
      builtIn: false,
      recommended: false,
      colorHex: json['color']?.toString() ?? '5146E5',
    );
  }
}

class SourceRegistry {
  static const _customKey = 'custom_sources_v05';
  static const _enabledKey = 'enabled_sources_v05';
  static const defaultBackend = 'https://flipradar-api-production-ec00.up.railway.app';

  static String _backendAdapter(String backendBase, String source) {
    final manual = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final b = manual.isEmpty ? defaultBackend : manual;
    return '$b/v1/market/search?source=$source&q={query}';
  }

  static List<PriceSource> builtIns({String backendBase = ''}) {
    return [
      PriceSource(
        id: 'ebay_de',
        name: 'eBay DE',
        subtitle: 'Wiederverkauf · aktuelle Angebote',
        searchUrlTemplate: 'https://www.ebay.de/sch/i.html?_nkw={query}',
        adapterUrlTemplate: _backendAdapter(backendBase, 'ebay_de'),
        role: 'resale',
        recommended: true,
        colorHex: '3665F3',
      ),
      const PriceSource(
        id: 'kleinanzeigen',
        name: 'Kleinanzeigen',
        subtitle: 'Lokaler Wiederverkauf',
        searchUrlTemplate: 'https://www.kleinanzeigen.de/s-{query}/k0',
        role: 'local',
        recommended: true,
        colorHex: '00A98F',
      ),
      PriceSource(
        id: 'amazon_de',
        name: 'Amazon DE',
        subtitle: 'Neupreis-Referenz · Keepa',
        searchUrlTemplate: 'https://www.amazon.de/s?k={query}',
        adapterUrlTemplate: _backendAdapter(backendBase, 'amazon_de'),
        role: 'retail',
        recommended: true,
        colorHex: 'FF9900',
      ),
      const PriceSource(
        id: 'mediamarkt',
        name: 'MediaMarkt',
        subtitle: 'Neupreis-Referenz',
        searchUrlTemplate: 'https://www.mediamarkt.de/de/search.html?query={query}',
        role: 'retail',
        colorHex: 'DF0000',
      ),
      const PriceSource(
        id: 'saturn',
        name: 'SATURN',
        subtitle: 'Neupreis-Referenz',
        searchUrlTemplate: 'https://www.saturn.de/de/search.html?query={query}',
        role: 'retail',
        colorHex: '1454A3',
      ),
      const PriceSource(
        id: 'idealo',
        name: 'idealo',
        subtitle: 'Neupreis-Vergleich',
        searchUrlTemplate: 'https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q={query}',
        role: 'retail',
        recommended: true,
        colorHex: 'FF6600',
      ),
      const PriceSource(
        id: 'rebuy',
        name: 'rebuy',
        subtitle: 'Sofort-Ankauf / Refurbished',
        searchUrlTemplate: 'https://www.rebuy.de/kaufen/suchen?q={query}',
        role: 'buyback',
        colorHex: '1B9E77',
      ),
      const PriceSource(
        id: 'backmarket',
        name: 'Back Market',
        subtitle: 'Refurbished-Referenz',
        searchUrlTemplate: 'https://www.backmarket.de/de-de/search?q={query}',
        role: 'refurb',
        colorHex: '111111',
      ),
    ];
  }

  static Future<List<PriceSource>> load({String backendBase = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList(_enabledKey)?.toSet();

    final built = builtIns(backendBase: backendBase)
        .map((s) => s.copyWith(enabled: enabled == null ? s.enabled : enabled.contains(s.id)))
        .toList();

    final custom = <PriceSource>[];
    for (final raw in prefs.getStringList(_customKey) ?? <String>[]) {
      try {
        final source = PriceSource.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        custom.add(source.copyWith(enabled: enabled == null ? source.enabled : enabled.contains(source.id)));
      } catch (_) {}
    }
    return [...built, ...custom];
  }

  static Future<void> save(List<PriceSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledKey,
      sources.where((s) => s.enabled).map((s) => s.id).toList(),
    );
    await prefs.setStringList(
      _customKey,
      sources.where((s) => !s.builtIn).map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  static Future<PriceSource> importManifest(String manifestUrl) async {
    final uri = Uri.tryParse(manifestUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Bitte eine gültige HTTPS-Adresse eingeben.');
    }
    final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !(isLocal && uri.scheme == 'http')) {
      throw const FormatException('Partner-Manifeste müssen HTTPS verwenden.');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Manifest konnte nicht geladen werden (${response.statusCode}).');
    }
    return PriceSource.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<SourceListing>> fetch(PriceSource source, String query) async {
    final target = source.adapterUrl(query);
    if (target == null) return [];
    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) return [];

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];

    final decoded = jsonDecode(response.body);
    final items = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>? ?? const [])
        : decoded is List<dynamic>
            ? decoded
            : const <dynamic>[];

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => SourceListing.fromJson(e, source))
        .where((e) => e.price > 0)
        .toList();
  }
}
