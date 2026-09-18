from pathlib import Path

p = Path('lib/v13_app.dart')
s = p.read_text()

marker = "v155-live-market-empty"
if marker in s:
    print('live market empty state already applied')
    raise SystemExit(0)

call_old = """          _V154LiveListingPreview(
            english: widget.english,
            listings: listings
                .where((e) => e.live && (e.role == 'resale' || e.role == 'local') && e.url.trim().isNotEmpty)
                .take(6)
                .toList(),
          ),
"""
call_new = """          _V154LiveListingPreview(
            english: widget.english,
            showEmpty: query.text.trim().isNotEmpty && pending.isEmpty,
            listings: listings
                .where((e) => e.live && (e.role == 'resale' || e.role == 'local') && e.url.trim().isNotEmpty)
                .take(6)
                .toList(),
          ),
"""
if call_old not in s:
    raise SystemExit('live listing call anchor not found')
s = s.replace(call_old, call_new, 1)

fields_old = """  final bool english;
  final List<SourceListing> listings;

  const _V154LiveListingPreview({required this.english, required this.listings});
"""
fields_new = """  final bool english;
  final bool showEmpty;
  final List<SourceListing> listings;

  const _V154LiveListingPreview({required this.english, required this.showEmpty, required this.listings});
"""
if fields_old not in s:
    raise SystemExit('live listing fields anchor not found')
s = s.replace(fields_old, fields_new, 1)

build_old = """  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return Container(
"""
build_new = """  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      if (!showEmpty) return const SizedBox.shrink();
      return Container(
        key: const ValueKey('v155-live-market-empty'),
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0D79A)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF9A6700)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Noch keine verifizierten LIVE-Angebote', 'No verified LIVE listings yet'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              t('Für diese Suche liefert aktuell keine angebundene LIVE-Quelle echte Angebote. Sandbox- oder Referenzwerte werden bewusst nicht als LIVE angezeigt.', 'No connected LIVE source currently returns real listings for this search. Sandbox or reference values are deliberately not shown as LIVE.'),
              style: const TextStyle(fontSize: 9.8, color: Color(0xFF6F6250)),
            ),
          ])),
        ]),
      );
    }
    return Container(
"""
if build_old not in s:
    raise SystemExit('live listing build anchor not found')
s = s.replace(build_old, build_new, 1)

p.write_text(s)
print('applied live market empty state')
