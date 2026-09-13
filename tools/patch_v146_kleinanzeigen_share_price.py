from pathlib import Path

app_path = Path('lib/v13_app.dart')
source_path = Path('lib/source_registry.dart')
server_path = Path('server/index.js')
pub_path = Path('pubspec.yaml')

app = app_path.read_text()
source = source_path.read_text()
server = server_path.read_text()
pub = pub_path.read_text()

pub = pub.replace('version: 0.14.5+28', 'version: 0.14.6+29', 1)

# SourceRegistry: safe shared-listing metadata model + backend resolver.
if 'class SharedListingMeta {' not in source:
    marker = 'class SourceListing {\n'
    block = '''class SharedListingMeta {
  final String source;
  final String title;
  final double price;
  final String currency;
  final String url;
  final String kind;

  const SharedListingMeta({
    required this.source,
    required this.title,
    required this.price,
    required this.currency,
    required this.url,
    required this.kind,
  });

  factory SharedListingMeta.fromJson(Map<String, dynamic> json) => SharedListingMeta(
        source: json['source']?.toString() ?? '',
        title: json['title']?.toString().trim() ?? '',
        price: SourceListing._toDouble(json['price']),
        currency: (json['currency']?.toString() ?? 'EUR').toUpperCase(),
        url: json['url']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
      );
}

'''
    assert marker in source
    source = source.replace(marker, block + marker, 1)

if 'static Uri? sharedListingUrl(String raw)' not in source:
    marker = '  static Future<List<PriceSource>> load({String backendBase = \'\'}) async {\n'
    block = r'''  static Uri? sharedListingUrl(String raw) {
    final matches = RegExp(r'https?://[^\s]+', caseSensitive: false).allMatches(raw);
    for (final match in matches) {
      var value = match.group(0) ?? '';
      value = value.replaceAll(RegExp(r'[\]\[),.;:]+$'), '');
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https') continue;
      final host = uri.host.toLowerCase();
      if (host != 'kleinanzeigen.de' && host != 'www.kleinanzeigen.de') continue;
      if (!uri.path.contains('/s-anzeige/')) continue;
      return uri;
    }
    return null;
  }

  static Future<SharedListingMeta?> resolveSharedListing(
    String raw, {
    String backendBase = '',
  }) async {
    final shared = sharedListingUrl(raw);
    if (shared == null) return null;
    final manual = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final base = manual.isEmpty ? defaultBackend : manual;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || baseUri.host.isEmpty || (baseUri.scheme != 'https' && baseUri.scheme != 'http')) {
      return null;
    }
    final endpoint = Uri.parse('$base/v1/listing/resolve').replace(
      queryParameters: {'url': shared.toString()},
    );
    final response = await http.get(endpoint).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    if (response.bodyBytes.length > 64 * 1024) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final meta = SharedListingMeta.fromJson(decoded);
    if (meta.source != 'kleinanzeigen' || meta.currency != 'EUR' || meta.price <= 0) return null;
    return meta;
  }

'''
    assert marker in source
    source = source.replace(marker, block + marker, 1)

# Check page: carry backend, allow injected resolver in tests and enrich missing buy price asynchronously.
old = '''  final V13SearchInput input;\n  final double targetRoi;\n'''
new = '''  final V13SearchInput input;\n  final String backendBase;\n  final Future<SharedListingMeta?> Function(String raw)? listingResolver;\n  final double targetRoi;\n'''
if old in app:
    app = app.replace(old, new, 1)

old = '''    required this.english,\n    required this.input,\n    required this.targetRoi,\n'''
new = '''    required this.english,\n    required this.input,\n    this.backendBase = '',\n    this.listingResolver,\n    required this.targetRoi,\n'''
if old in app:
    app = app.replace(old, new, 1)

old = '''            input: normalized,\n            targetRoi: widget.targetRoi,\n'''
new = '''            input: normalized,\n            backendBase: widget.backend,\n            targetRoi: widget.targetRoi,\n'''
if old in app:
    app = app.replace(old, new, 1)

old = '''  bool savedBought = false;\n  int token = 0;\n'''
new = '''  bool savedBought = false;\n  bool listingResolving = false;\n  bool listingResolved = false;\n  bool listingResolveFailed = false;\n  int token = 0;\n'''
if old in app:
    app = app.replace(old, new, 1)

old = '''    if (detected != null && detected > 0) {\n      buy.text = detected == detected.roundToDouble()\n          ? detected.toStringAsFixed(0)\n          : detected.toStringAsFixed(2).replaceAll('.', ',');\n    }\n    WidgetsBinding.instance.addPostFrameCallback((_) => _search());\n  }\n\n  Future<void> _search() async {\n'''
new = '''    if (detected != null && detected > 0) {\n      buy.text = detected == detected.roundToDouble()\n          ? detected.toStringAsFixed(0)\n          : detected.toStringAsFixed(2).replaceAll('.', ',');\n    }\n    final canResolveListing = detected == null && SourceRegistry.sharedListingUrl(widget.input.raw) != null;\n    listingResolving = canResolveListing;\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      _search();\n      if (canResolveListing) unawaited(_resolveSharedListing());\n    });\n  }\n\n  Future<void> _resolveSharedListing() async {\n    SharedListingMeta? meta;\n    try {\n      final injected = widget.listingResolver;\n      meta = injected != null\n          ? await injected(widget.input.raw)\n          : await SourceRegistry.resolveSharedListing(widget.input.raw, backendBase: widget.backendBase);\n    } catch (_) {}\n    if (!mounted) return;\n    if (meta != null && meta.price > 0) {\n      if (buyPrice <= 0) {\n        buy.text = meta.price == meta.price.roundToDouble()\n            ? meta.price.toStringAsFixed(0)\n            : meta.price.toStringAsFixed(2).replaceAll('.', ',');\n      }\n      setState(() {\n        listingResolving = false;\n        listingResolved = true;\n        listingResolveFailed = false;\n      });\n      return;\n    }\n    setState(() {\n      listingResolving = false;\n      listingResolved = false;\n      listingResolveFailed = true;\n    });\n  }\n\n  Future<void> _search() async {\n'''
if old in app:
    app = app.replace(old, new, 1)

app = app.replace(
    '''    if (direct.isEmpty) {\n      WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());\n      return;\n    }\n''',
    '''    if (direct.isEmpty) {\n      if (!listingResolving) WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());\n      return;\n    }\n''',
    1,
)
app = app.replace(
    '''    if (buy.text.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());\n''',
    '''    if (buy.text.isEmpty && !listingResolving) WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());\n''',
    1,
)

old = '''          if (widget.input.detectedPrice != null) ...[\n            const SizedBox(height: 4),\n            Text(t('Angebotspreis automatisch erkannt – kurz prüfen und bei Bedarf ändern.', 'Listing price detected automatically – quickly verify and edit if needed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483))),\n          ],\n'''
new = '''          if (listingResolving) ...[\n            const SizedBox(height: 5),\n            Row(key: const ValueKey('v146-listing-resolving'), children: [\n              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),\n              const SizedBox(width: 7),\n              Expanded(child: Text(t('Kleinanzeigen-Preis wird aus dem geteilten Link geladen …', 'Loading the Kleinanzeigen price from the shared link …'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483)))),\n            ]),\n          ] else if (listingResolved) ...[\n            const SizedBox(height: 4),\n            Text(key: const ValueKey('v146-listing-resolved'), t('Angebotspreis aus dem Kleinanzeigen-Link geladen – kurz prüfen und bei Bedarf ändern.', 'Listing price loaded from the Kleinanzeigen link – quickly verify and edit if needed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF087F5B), fontWeight: FontWeight.w700)),\n          ] else if (listingResolveFailed) ...[\n            const SizedBox(height: 4),\n            Text(key: const ValueKey('v146-listing-failed'), t('Preis konnte aus dem Kleinanzeigen-Link nicht geladen werden – bitte manuell eintragen.', 'Could not load the price from the Kleinanzeigen link – please enter it manually.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFFC47B00))),\n          ] else if (widget.input.detectedPrice != null) ...[\n            const SizedBox(height: 4),\n            Text(t('Angebotspreis automatisch erkannt – kurz prüfen und bei Bedarf ändern.', 'Listing price detected automatically – quickly verify and edit if needed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483))),\n          ],\n'''
if old in app:
    app = app.replace(old, new, 1)

# Backend: add resolver import and GET endpoint. The resolver itself enforces the Kleinanzeigen host allowlist and redirect checks.
if "require('./listing_resolver')" not in server:
    server = server.replace(
        "const { filterMarketListings } = require('./market_quality');\n",
        "const { filterMarketListings } = require('./market_quality');\nconst { resolvePublicListing } = require('./listing_resolver');\n",
        1,
    )

if "url.pathname === '/v1/listing/resolve'" not in server:
    marker = "    if (req.method === 'GET' && url.pathname === '/v1/market/search') {\n"
    block = '''    if (req.method === 'GET' && url.pathname === '/v1/listing/resolve') {\n      pruneRateBuckets();\n      if (!allowRequest(req)) {\n        return json(res, 429, { error: 'rate_limit' });\n      }\n      const listingUrl = String(url.searchParams.get('url') || '').trim();\n      if (!listingUrl) return json(res, 400, { error: 'url is required' });\n      try {\n        const result = await resolvePublicListing(listingUrl);\n        return json(res, 200, result);\n      } catch (error) {\n        const message = error?.name === 'AbortError'\n          ? 'upstream_timeout'\n          : error instanceof Error\n            ? error.message\n            : String(error);\n        const status = message === 'unsupported_listing_url' ? 400 : 502;\n        return json(res, status, { error: message });\n      }\n    }\n\n'''
    assert marker in server
    server = server.replace(marker, block + marker, 1)

server = server.replace("version: '0.10.0'", "version: '0.11.0'", 1)

assert 'version: 0.14.6+29' in pub
assert 'class SharedListingMeta {' in source
assert 'static Uri? sharedListingUrl(String raw)' in source
assert 'resolveSharedListing(' in source
assert 'backendBase: widget.backend' in app
assert 'Future<void> _resolveSharedListing()' in app
assert "ValueKey('v146-listing-resolved')" in app
assert "require('./listing_resolver')" in server
assert "url.pathname === '/v1/listing/resolve'" in server

app_path.write_text(app)
source_path.write_text(source)
server_path.write_text(server)
pub_path.write_text(pub)
print('V0.14.6 Kleinanzeigen share-price patch applied')
