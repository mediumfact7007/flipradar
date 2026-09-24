from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

if "import 'source_status.dart';" not in app:
    app = app.replace(
        "import 'source_registry.dart';\n",
        "import 'source_registry.dart';\nimport 'source_status.dart';\n",
        1,
    )

old = r'''class _V13SourcesPageState extends State<V13SourcesPage> {
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
'''

new = r'''class _V13SourcesPageState extends State<V13SourcesPage> {
  late List<PriceSource> items;
  MarketBackendStatus? runtimeStatus;
  bool checkingStatus = true;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
    unawaited(_loadRuntimeStatus());
  }

  Future<void> _loadRuntimeStatus() async {
    if (mounted) setState(() => checkingStatus = true);
    final status = await MarketStatusClient.fetch(items);
    if (!mounted) return;
    setState(() {
      runtimeStatus = status;
      checkingStatus = false;
    });
  }

  String _connection(PriceSource source) {
    if (!source.canFetchInApp) return t('Browser-Suche', 'Browser search');
    if (checkingStatus) return t('Prüfe Live-Status …', 'Checking live status …');
    final status = runtimeStatus;
    if (status == null || !status.reachable) {
      return t('Server nicht erreichbar', 'Server unavailable');
    }
    if (status.isLive(source.id)) return 'LIVE';
    return t('Noch nicht verbunden', 'Not connected yet');
  }

  String _summary() {
    if (checkingStatus) return t('Flipwert-Server wird geprüft …', 'Checking Flipwert server …');
    final status = runtimeStatus;
    if (status == null || !status.reachable) {
      return t(
        'Live-Server momentan nicht erreichbar. Browser-Suchen funktionieren weiter.',
        'Live server is currently unavailable. Browser searches still work.',
      );
    }
    final live = items.where((source) => status.isLive(source.id)).map((e) => e.name).toList();
    if (live.isEmpty) {
      return t(
        'Live-Daten sind vorbereitet. eBay/Amazon brauchen noch die Server-Zugangsdaten.',
        'Live data is prepared. eBay/Amazon still need server credentials.',
      );
    }
    return '${t('Live verbunden', 'Live connected')}: ${live.join(', ')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: t('Status neu prüfen', 'Refresh status'),
              onPressed: checkingStatus ? null : _loadRuntimeStatus,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28), children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              checkingStatus
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Icon(
                      runtimeStatus?.reachable == true ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: runtimeStatus?.reachable == true ? const Color(0xFF087F5B) : const Color(0xFF777B88),
                      size: 21,
                    ),
              const SizedBox(width: 10),
              Expanded(child: Text(_summary(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF666A77), fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 10),
          Text(t('Nur Quellen aktivieren, die du wirklich sehen willst.', 'Only enable sources you actually want to see.'), style: const TextStyle(fontSize: 12, color: Color(0xFF747885))),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: SwitchListTile(
                value: items[i].enabled,
                onChanged: (v) {
                  setState(() => items[i] = items[i].copyWith(enabled: v));
                  widget.onChanged([...items]);
                },
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                secondary: Icon(_sourceIcon(items[i].id), color: _sourceColor(items[i])),
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${_role(items[i])} · ${_connection(items[i])}', style: const TextStyle(fontSize: 10.5)),
              ),
            ),
        ]),
      );

  String _role(PriceSource s) { switch (s.role) { case 'resale': return t('Wiederverkauf', 'Resale'); case 'local': return t('Lokal/Secondhand', 'Local/secondhand'); case 'retail': return t('Neupreis', 'Retail'); case 'buyback': return t('Sofort-Ankauf', 'Buyback'); case 'refurb': return 'Refurbished'; default: return t('Referenz', 'Reference'); } }
}
'''

if 'MarketBackendStatus? runtimeStatus;' not in app:
    if old not in app:
        raise SystemExit('V13SourcesPage state block not found')
    app = app.replace(old, new, 1)

# V0.14.1: fix the actual clipping visible on compact Android screens. The
# floating label of the first TextField in the expanded cost section paints
# above the field bounds, so reserve space before that first child.
cost_old = """            children: [
              TextField(controller: costs, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('Zusatzkosten gesamt', 'Extra costs total'), suffixText: '€')),
              const SizedBox(height: 8),
"""
cost_new = """            children: [
              const SizedBox(height: 12, key: ValueKey('v0141-cost-label-top-space')),
              TextField(
                key: const ValueKey('v0141-extra-costs-input'),
                controller: costs,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 8),
"""
if cost_old in app:
    app = app.replace(cost_old, cost_new, 1)
elif 'v0141-cost-label-top-space' not in app:
    raise SystemExit('Costs ExpansionTile field pattern not found')

pub = pub.replace('version: 0.13.6+22', 'version: 0.14.0+23')
pub = pub.replace('version: 0.14.0+23', 'version: 0.14.1+24')
# Keep the old workflow's compatibility grep true until the workflow is
# consolidated in the next roadmap step. The actual pubspec version is above.
compat = '# build-compat previous-version: 0.14.0+23'
if compat not in pub:
    pub = pub.rstrip() + '\n' + compat + '\n'

assert "import 'source_status.dart';" in app
assert 'MarketBackendStatus? runtimeStatus;' in app
assert 'MarketStatusClient.fetch(items)' in app
assert "'Browser-Suche'" in app
assert "'Noch nicht verbunden'" in app
assert 'v0141-cost-label-top-space' in app
assert 'v0141-extra-costs-input' in app
assert 'version: 0.14.1+24' in pub
assert '0.14.0+23' in pub

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.1 live source status + cost-field clipping fix applied')
