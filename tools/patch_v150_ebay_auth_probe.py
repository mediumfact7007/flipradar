from pathlib import Path

server_path = Path('server/index.js')
status_path = Path('lib/source_status.dart')
pub_path = Path('pubspec.yaml')

server = server_path.read_text()
status = status_path.read_text()
pub = pub_path.read_text()

old_source_status = '''function sourceStatus() {
  return {
    ebay_de: {
      configured: Boolean(EBAY_CLIENT_ID && EBAY_CLIENT_SECRET),
      mode: 'official_api',
      estimate: 'used_fixed_price_active_listings',
    },
    amazon_de: {
      configured: Boolean(KEEPA_API_KEY),
      mode: 'keepa',
      estimate: 'retail_reference',
    },
    kleinanzeigen: { configured: false, mode: 'official_search_link' },
    mediamarkt: { configured: false, mode: 'official_search_link' },
    saturn: { configured: false, mode: 'official_search_link' },
    idealo: { configured: false, mode: 'official_search_link' },
  };
}
'''

new_source_status = '''async function sourceStatus(probe = false) {
  const ebayConfigured = Boolean(EBAY_CLIENT_ID && EBAY_CLIENT_SECRET);
  let ebayAuth = ebayConfigured ? 'unknown' : 'missing';
  if (probe && ebayConfigured) {
    try {
      await getEbayToken();
      ebayAuth = 'ok';
    } catch (_) {
      ebayAuth = 'invalid';
    }
  }

  return {
    ebay_de: {
      configured: ebayConfigured,
      ready: ebayAuth === 'ok',
      auth: ebayAuth,
      mode: 'official_api',
      estimate: 'used_fixed_price_active_listings',
    },
    amazon_de: {
      configured: Boolean(KEEPA_API_KEY),
      ready: Boolean(KEEPA_API_KEY),
      auth: KEEPA_API_KEY ? 'configured' : 'missing',
      mode: 'keepa',
      estimate: 'retail_reference',
    },
    kleinanzeigen: { configured: false, ready: false, auth: 'browser', mode: 'official_search_link' },
    mediamarkt: { configured: false, ready: false, auth: 'browser', mode: 'official_search_link' },
    saturn: { configured: false, ready: false, auth: 'browser', mode: 'official_search_link' },
    idealo: { configured: false, ready: false, auth: 'browser', mode: 'official_search_link' },
  };
}
'''

if 'async function sourceStatus(probe = false)' not in server:
    if old_source_status not in server:
        raise SystemExit('sourceStatus block not found')
    server = server.replace(old_source_status, new_source_status, 1)

old_route = """    if (req.method === 'GET' && url.pathname === '/v1/status') {
      return json(res, 200, { sources: sourceStatus() });
    }
"""
new_route = """    if (req.method === 'GET' && url.pathname === '/v1/status') {
      const probe = url.searchParams.get('probe') === '1';
      return json(res, 200, { sources: await sourceStatus(probe) });
    }
"""
if "await sourceStatus(probe)" not in server:
    if old_route not in server:
        raise SystemExit('status route not found')
    server = server.replace(old_route, new_route, 1)

old_runtime = '''class SourceRuntimeStatus {
  final bool configured;
  final String mode;
  final String estimate;

  const SourceRuntimeStatus({
    required this.configured,
    required this.mode,
    this.estimate = '',
  });

  factory SourceRuntimeStatus.fromJson(Map<String, dynamic> json) =>
      SourceRuntimeStatus(
        configured: json['configured'] == true,
        mode: json['mode']?.toString() ?? '',
        estimate: json['estimate']?.toString() ?? '',
      );
}
'''
new_runtime = '''class SourceRuntimeStatus {
  final bool configured;
  final bool ready;
  final String auth;
  final String mode;
  final String estimate;

  const SourceRuntimeStatus({
    required this.configured,
    required this.ready,
    required this.auth,
    required this.mode,
    this.estimate = '',
  });

  factory SourceRuntimeStatus.fromJson(Map<String, dynamic> json) =>
      SourceRuntimeStatus(
        configured: json['configured'] == true,
        ready: json['ready'] == true,
        auth: json['auth']?.toString() ?? '',
        mode: json['mode']?.toString() ?? '',
        estimate: json['estimate']?.toString() ?? '',
      );
}
'''
if 'final String auth;' not in status:
    if old_runtime not in status:
        raise SystemExit('SourceRuntimeStatus block not found')
    status = status.replace(old_runtime, new_runtime, 1)

old_live = '''  bool isLive(String sourceId) =>
      reachable && (sources[sourceId]?.configured ?? false);
'''
new_live = '''  bool isLive(String sourceId) {
    final s = sources[sourceId];
    return reachable && s != null && s.configured && (s.ready || s.auth == 'ok');
  }
'''
if "s.auth == 'ok'" not in status:
    if old_live not in status:
        raise SystemExit('isLive block not found')
    status = status.replace(old_live, new_live, 1)

old_endpoint = '''      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/v1/status',
      );
'''
new_endpoint = '''      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/v1/status',
        queryParameters: const {'probe': '1'},
      );
'''
if "queryParameters: const {'probe': '1'}" not in status:
    if old_endpoint not in status:
        raise SystemExit('status endpoint block not found')
    status = status.replace(old_endpoint, new_endpoint, 1)

pub = pub.replace('version: 0.14.1+24', 'version: 0.15.0+25')
if '# build-compat previous-version: 0.14.0+23' in pub:
    pub = pub.replace('# build-compat previous-version: 0.14.0+23', '# build-compat previous-version: 0.14.1+24')

assert 'async function sourceStatus(probe = false)' in server
assert "auth: 'missing'" in server
assert "auth: 'ok'" in server
assert "auth: 'invalid'" in server
assert "await sourceStatus(probe)" in server
assert 'final String auth;' in status
assert "s.auth == 'ok'" in status
assert "queryParameters: const {'probe': '1'}" in status
assert 'version: 0.15.0+25' in pub

server_path.write_text(server)
status_path.write_text(status)
pub_path.write_text(pub)
print('V0.15 eBay auth readiness patch applied')
