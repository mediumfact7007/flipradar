from pathlib import Path

app_path = Path('lib/v13_app.dart')
pub_path = Path('pubspec.yaml')
app = app_path.read_text()
pub = pub_path.read_text()

pub = pub.replace('version: 0.14.4+27', 'version: 0.14.5+28', 1)

# 1) Restore share-to-Flipwert safely after the first frame, never during first-frame startup.
old = """  @override\n  void initState() {\n    super.initState();\n    // Safe-start build: optional share listener is not part of first-frame startup.\n  }\n"""
new = """  @override\n  void initState() {\n    super.initState();\n    // Keep first-frame startup clean, then restore the native share listener.\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n      if (Platform.isAndroid || Platform.isIOS) _listenShares();\n    });\n  }\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """  void _listenShares() {\n    try {\n"""
new = """  void _listenShares() {\n    if (shareSub != null) return;\n    try {\n"""
if old in app:
    app = app.replace(old, new, 1)

# 2) One-tap jump to open flips from home.
old = """        onSettings: _settings,\n      ),\n"""
new = """        onSettings: _settings,\n        onOpenFlips: () => setState(() => tab = 1),\n      ),\n"""
if old in app and 'onOpenFlips: () => setState(() => tab = 1)' not in app:
    app = app.replace(old, new, 1)

old = """  final VoidCallback onSettings;\n\n  const V13Home({\n"""
new = """  final VoidCallback onSettings;\n  final VoidCallback onOpenFlips;\n\n  const V13Home({\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """    required this.onSettings,\n  });\n"""
new = """    required this.onSettings,\n    required this.onOpenFlips,\n  });\n"""
if old in app:
    app = app.replace(old, new, 1)

# Preserve the raw pasted/shared text so detected listing prices are not lost.
old = """  void _submit([String? value]) {\n    final normalized = normalizeV13Search(value ?? query.text);\n    if (normalized.query.isNotEmpty) widget.onSearch(normalized.query);\n  }\n"""
new = """  void _submit([String? value]) {\n    final raw = value ?? query.text;\n    final normalized = normalizeV13Search(raw);\n    if (normalized.query.isNotEmpty) widget.onSearch(raw);\n  }\n\n  void _clearSearch() {\n    query.clear();\n    setState(() => preview = const V13SearchInput(raw: '', query: '', kind: V13InputKind.text));\n  }\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """            suffixIcon: IconButton(onPressed: _paste, tooltip: t('Einfügen', 'Paste'), icon: const Icon(Icons.content_paste_rounded)),\n"""
new = """            suffixIcon: query.text.trim().isEmpty\n                ? IconButton(onPressed: _paste, tooltip: t('Einfügen', 'Paste'), icon: const Icon(Icons.content_paste_rounded))\n                : IconButton(key: const ValueKey('v145-clear-search'), onPressed: _clearSearch, tooltip: t('Leeren', 'Clear'), icon: const Icon(Icons.close_rounded)),\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """        if (widget.openFlips > 0) ...[\n          const SizedBox(height: 13),\n          Text(t('${widget.openFlips} offene Flips warten auf Verkauf.', '${widget.openFlips} open flips are waiting to sell.'), style: const TextStyle(fontSize: 12, color: Color(0xFF777B88))),\n        ],\n"""
new = """        if (widget.openFlips > 0) ...[\n          const SizedBox(height: 13),\n          OutlinedButton.icon(\n            key: const ValueKey('v145-open-flips'),\n            onPressed: widget.onOpenFlips,\n            icon: const Icon(Icons.inventory_2_outlined, size: 18),\n            label: Text(t('${widget.openFlips} offene Flips ansehen', 'View ${widget.openFlips} open flips')),\n          ),\n        ],\n"""
if old in app:
    app = app.replace(old, new, 1)

# 3) Failed source tracking + retry instead of silently swallowing failures.
old = """  List<SourceListing> listings = [];\n  final Set<String> pending = {};\n  bool manualMode = false;\n"""
new = """  List<SourceListing> listings = [];\n  final Set<String> pending = {};\n  final Set<String> failed = {};\n  bool manualMode = false;\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """      listings = [];\n      pending.clear();\n      manualCommitted = null;\n"""
new = """      listings = [];\n      pending.clear();\n      failed.clear();\n      manualCommitted = null;\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """  Future<void> _fetchOne(PriceSource source, String q, int myToken) async {\n    List<SourceListing> result = [];\n    try {\n      result = await SourceRegistry.fetch(source, q);\n    } catch (_) {}\n    if (!mounted || myToken != token) return;\n"""
new = """  Future<void> _fetchOne(PriceSource source, String q, int myToken) async {\n    List<SourceListing> result = [];\n    var didFail = false;\n    try {\n      result = await SourceRegistry.fetch(source, q);\n    } catch (_) {\n      didFail = true;\n    }\n    if (!mounted || myToken != token) return;\n"""
if old in app:
    app = app.replace(old, new, 1)

old = """    pending.remove(source.id);\n    setState(() => listings = dedupe.values.toList()..sort((a, b) => a.total.compareTo(b.total)));\n"""
new = """    pending.remove(source.id);\n    if (didFail) {\n      failed.add(source.id);\n    } else {\n      failed.remove(source.id);\n    }\n    setState(() => listings = dedupe.values.toList()..sort((a, b) => a.total.compareTo(b.total)));\n"""
if old in app:
    app = app.replace(old, new, 1)

marker = """  List<double> _valuesFor(Set<String> roles) => listings\n"""
retry_method = """  void _retryFailed() {\n    if (failed.isEmpty) return;\n    final q = normalizeV13Search(query.text).query;\n    if (q.isEmpty) return;\n    final ids = failed.toSet();\n    final retry = widget.sources\n        .where((s) => ids.contains(s.id) && s.enabled && s.canFetchInApp)\n        .toList();\n    if (retry.isEmpty) {\n      setState(() => failed.clear());\n      return;\n    }\n    final myToken = token;\n    setState(() {\n      for (final source in retry) {\n        failed.remove(source.id);\n        pending.add(source.id);\n      }\n    });\n    for (final source in retry) {\n      unawaited(_fetchOne(source, q, myToken));\n    }\n  }\n\n"""
if marker in app and 'void _retryFailed()' not in app:
    app = app.replace(marker, retry_method + marker, 1)

old = """          _V13SourceScroller(\n            english: widget.english,\n            sources: visibleSources,\n            priceFor: _sourceMedian,\n            onOpen: _openSource,\n            onEbaySold: _openEbaySold,\n          ),\n          const SizedBox(height: 12),\n"""
new = """          _V13SourceScroller(\n            english: widget.english,\n            sources: visibleSources,\n            priceFor: _sourceMedian,\n            onOpen: _openSource,\n            onEbaySold: _openEbaySold,\n          ),\n          if (failed.isNotEmpty) ...[\n            const SizedBox(height: 7),\n            _V145RetrySources(english: widget.english, failed: failed.length, onRetry: _retryFailed),\n          ],\n          const SizedBox(height: 12),\n"""
if old in app:
    app = app.replace(old, new, 1)

marker = """class _V13SourceScroller extends StatelessWidget {\n"""
retry_widget = r'''class _V145RetrySources extends StatelessWidget {
  final bool english;
  final int failed;
  final VoidCallback onRetry;
  const _V145RetrySources({required this.english, required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFC47B00)),
        const SizedBox(width: 6),
        Expanded(child: Text(
          english ? '$failed source(s) could not be reached.' : '$failed Quelle(n) nicht erreichbar.',
          style: const TextStyle(fontSize: 10.8, color: Color(0xFF6C7080)),
        )),
        TextButton.icon(
          key: const ValueKey('v145-retry-sources'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(english ? 'Retry' : 'Erneut'),
        ),
      ]);
}

'''
if marker in app and 'class _V145RetrySources extends StatelessWidget' not in app:
    app = app.replace(marker, retry_widget + marker, 1)

assert "version: 0.14.5+28" in pub
assert "Platform.isAndroid || Platform.isIOS" in app
assert "if (shareSub != null) return;" in app
assert "ValueKey('v145-open-flips')" in app
assert "ValueKey('v145-clear-search')" in app
assert "void _retryFailed()" in app
assert "ValueKey('v145-retry-sources')" in app
assert "widget.onSearch(raw)" in app

app_path.write_text(app)
pub_path.write_text(pub)
print('V0.14.5 streamline patch applied')
