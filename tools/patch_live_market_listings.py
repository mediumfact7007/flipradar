from pathlib import Path

p = Path('lib/v13_app.dart')
s = p.read_text()

marker = "class _V154LiveListingPreview extends StatelessWidget"
if marker in s:
    print('live listing preview already applied')
    raise SystemExit(0)

needle = """          _V13SourceScroller(
            english: widget.english,
            sources: visibleSources,
            priceFor: _sourceMedian,
            onOpen: _openSource,
            onEbaySold: _openEbaySold,
          ),
          if (failed.isNotEmpty) ...[
"""
replacement = """          _V13SourceScroller(
            english: widget.english,
            sources: visibleSources,
            priceFor: _sourceMedian,
            onOpen: _openSource,
            onEbaySold: _openEbaySold,
          ),
          _V154LiveListingPreview(
            english: widget.english,
            listings: listings
                .where((e) => e.live && (e.role == 'resale' || e.role == 'local') && e.url.trim().isNotEmpty)
                .take(6)
                .toList(),
          ),
          if (failed.isNotEmpty) ...[
"""
if needle not in s:
    raise SystemExit('check-page source scroller anchor not found')
s = s.replace(needle, replacement, 1)

anchor = "class _V13DecisionCard extends StatelessWidget {"
widget = r'''class _V154LiveListingPreview extends StatelessWidget {
  final bool english;
  final List<SourceListing> listings;

  const _V154LiveListingPreview({required this.english, required this.listings});

  String t(String de, String en) => english ? en : de;

  Future<void> _open(SourceListing listing) async {
    final uri = Uri.tryParse(listing.url.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('v154-live-market-listings'),
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E6EE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.public_rounded, size: 17, color: Color(0xFF087F5B)),
          const SizedBox(width: 6),
          Expanded(child: Text(t('Aktuelle Angebote', 'Current listings'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5))),
          const _V13Pill(text: 'LIVE', foreground: Color(0xFF087F5B), background: Color(0xFFE8F7F1)),
        ]),
        const SizedBox(height: 3),
        Text(
          t('Nur echte LIVE-Treffer aus angebundenen Marktplätzen – Sandbox/Referenzwerte erscheinen hier nicht.', 'Only real LIVE results from connected marketplaces – sandbox/reference values are not shown here.'),
          style: const TextStyle(fontSize: 9.8, color: Color(0xFF777B88)),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < listings.length; i++) ...[
          InkWell(
            onTap: () => _open(listings[i]),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(listings[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${listings[i].sourceName}${listings[i].condition.trim().isEmpty ? '' : ' · ${listings[i].condition.trim()}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF777B88)),
                  ),
                ])),
                const SizedBox(width: 8),
                Text(v13Euro(listings[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF777B88)),
              ]),
            ),
          ),
          if (i != listings.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

'''
if anchor not in s:
    raise SystemExit('decision-card anchor not found')
s = s.replace(anchor, widget + anchor, 1)
p.write_text(s)
print('applied live market listing preview')
