from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')

app = app_path.read_text()
pub = pub_path.read_text()

# Never allow Sandbox/mock/reference payloads (live:false) to influence
# automatic market medians, expected sale price, MAX buy or source medians.
old_values = """  List<double> _valuesFor(Set<String> roles) => listings
      .where((e) => roles.contains(e.role))
"""
new_values = """  List<double> _valuesFor(Set<String> roles) => listings
      .where((e) => e.live && roles.contains(e.role))
"""
if old_values in app:
    app = app.replace(old_values, new_values, 1)
elif "e.live && roles.contains(e.role)" not in app:
    raise SystemExit('_valuesFor live-data guard pattern not found')

old_source_median = """  double? _sourceMedian(String id) => _median(_clean(listings.where((e) => e.sourceId == id).map((e) => e.total).where((e) => e > 0).toList()));
"""
new_source_median = """  double? _sourceMedian(String id) => _median(_clean(listings.where((e) => e.live && e.sourceId == id).map((e) => e.total).where((e) => e > 0).toList()));
"""
if old_source_median in app:
    app = app.replace(old_source_median, new_source_median, 1)
elif "e.live && e.sourceId == id" not in app:
    raise SystemExit('_sourceMedian live-data guard pattern not found')

# Make the source screen explicitly distinguish connected Sandbox from LIVE.
old_connection = """    if (status == null || !status.reachable) {
      return t('Server nicht erreichbar', 'Server unavailable');
    }
    if (status.isLive(source.id)) return 'LIVE';
    return t('Noch nicht verbunden', 'Not connected yet');
"""
new_connection = """    if (status == null || !status.reachable) {
      return t('Server nicht erreichbar', 'Server unavailable');
    }
    if (status.isSandbox(source.id)) return 'SANDBOX';
    if (status.isLive(source.id)) return 'LIVE';
    return t('Noch nicht verbunden', 'Not connected yet');
"""
if old_connection in app:
    app = app.replace(old_connection, new_connection, 1)
elif "status.isSandbox(source.id)" not in app:
    raise SystemExit('source connection status pattern not found')

old_summary = """    final live = items.where((source) => status.isLive(source.id)).map((e) => e.name).toList();
    if (live.isEmpty) {
      return t(
        'Live-Daten sind vorbereitet. eBay/Amazon brauchen noch die Server-Zugangsdaten.',
        'Live data is prepared. eBay/Amazon still need server credentials.',
      );
    }
    return '${t('Live verbunden', 'Live connected')}: ${live.join(', ')}';
"""
new_summary = """    final sandbox = items.where((source) => status.isSandbox(source.id)).map((e) => e.name).toList();
    final live = items.where((source) => status.isLive(source.id)).map((e) => e.name).toList();
    if (sandbox.isNotEmpty && live.isEmpty) {
      return t(
        'eBay Sandbox verbunden. Testdaten werden niemals für Kaufentscheidungen oder MAX-Preise verwendet.',
        'eBay Sandbox connected. Test data is never used for buy decisions or MAX prices.',
      );
    }
    if (live.isEmpty) {
      return t(
        'Live-Daten sind vorbereitet. eBay/Amazon brauchen noch die Server-Zugangsdaten.',
        'Live data is prepared. eBay/Amazon still need server credentials.',
      );
    }
    return '${t('Live verbunden', 'Live connected')}: ${live.join(', ')}';
"""
if old_summary in app:
    app = app.replace(old_summary, new_summary, 1)
elif "eBay Sandbox verbunden" not in app:
    raise SystemExit('source summary status pattern not found')

# V0.14.2 build number. Accept reruns where the source is already finalized.
if 'version: 0.14.2+25' not in pub:
    pub = pub.replace('version: 0.14.1+24', 'version: 0.14.2+25')

assert "e.live && roles.contains(e.role)" in app
assert "e.live && e.sourceId == id" in app
assert "status.isSandbox(source.id)" in app
assert "eBay Sandbox verbunden" in app
assert 'version: 0.14.2+25' in pub

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.2 non-live market-data guard applied')
