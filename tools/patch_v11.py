from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected exactly one match, found {count}')
    p.write_text(text.replace(old, new, 1))


# Version bump.
replace_once(
    'pubspec.yaml',
    'version: 0.10.2+13',
    'version: 0.11.0+14',
)

# Add two useful Germany/Europe-facing search portals. They are search links only;
# no private/unofficial API is used and they do not influence the automatic verdict.
replace_once(
    'lib/source_registry.dart',
    """      const PriceSource(
        id: 'kleinanzeigen',
        name: 'Kleinanzeigen',
        subtitle: 'Lokaler Wiederverkauf',
        searchUrlTemplate: 'https://www.kleinanzeigen.de/s-{query}/k0',
        role: 'local',
        recommended: true,
        trustedForDecision: true,
        colorHex: '00A98F',
      ),
      PriceSource(
        id: 'amazon_de',
""",
    """      const PriceSource(
        id: 'kleinanzeigen',
        name: 'Kleinanzeigen',
        subtitle: 'Lokaler Wiederverkauf',
        searchUrlTemplate: 'https://www.kleinanzeigen.de/s-{query}/k0',
        role: 'local',
        recommended: true,
        trustedForDecision: true,
        colorHex: '00A98F',
      ),
      const PriceSource(
        id: 'vinted',
        name: 'Vinted',
        subtitle: 'Secondhand · Mode, Elektronik & mehr',
        searchUrlTemplate: 'https://www.vinted.de/catalog?search_text={query}',
        role: 'local',
        recommended: true,
        colorHex: '007782',
      ),
      PriceSource(
        id: 'amazon_de',
""",
)

replace_once(
    'lib/source_registry.dart',
    """      const PriceSource(
        id: 'idealo',
        name: 'idealo',
        subtitle: 'Neupreis-Vergleich',
        searchUrlTemplate: 'https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q={query}',
        role: 'retail',
        recommended: true,
        trustedForDecision: true,
        colorHex: 'FF6600',
      ),
      const PriceSource(
        id: 'rebuy',
""",
    """      const PriceSource(
        id: 'idealo',
        name: 'idealo',
        subtitle: 'Neupreis-Vergleich',
        searchUrlTemplate: 'https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q={query}',
        role: 'retail',
        recommended: true,
        trustedForDecision: true,
        colorHex: 'FF6600',
      ),
      const PriceSource(
        id: 'geizhals',
        name: 'Geizhals',
        subtitle: 'Neupreis- & Angebotsvergleich',
        searchUrlTemplate: 'https://geizhals.de/?fs={query}&hloc=de',
        role: 'retail',
        recommended: true,
        colorHex: '0096D6',
      ),
      const PriceSource(
        id: 'rebuy',
""",
)

replace_once(
    'lib/v07_widgets.dart',
    """    case 'kleinanzeigen':
      return Icons.location_on_outlined;
    case 'amazon_de':
""",
    """    case 'kleinanzeigen':
      return Icons.location_on_outlined;
    case 'vinted':
      return Icons.checkroom_outlined;
    case 'amazon_de':
""",
)

replace_once(
    'lib/v07_widgets.dart',
    """    case 'idealo':
      return Icons.compare_arrows;
    case 'rebuy':
""",
    """    case 'idealo':
      return Icons.compare_arrows;
    case 'geizhals':
      return Icons.query_stats_outlined;
    case 'rebuy':
""",
)

# Add source-level medians and lightweight category-aware ordering. Nothing is
# hidden; the most useful portals simply appear first for the current item.
replace_once(
    'lib/v10_app.dart',
    """  double? get resaleMedian => _median(_clean(_resaleValues()));
  double? get retailMedian => _median(_clean(_retailValues()));
  double? get buybackMedian => _median(_clean(_buybackValues()));

  double? get targetSell {
""",
    """  double? get resaleMedian => _median(_clean(_resaleValues()));
  double? get retailMedian => _median(_clean(_retailValues()));
  double? get buybackMedian => _median(_clean(_buybackValues()));

  double? _sourceMedian(String sourceId) {
    final values = listings
        .where((e) => e.sourceId == sourceId)
        .map((e) => e.total)
        .where((e) => e > 0 && e.isFinite)
        .toList();
    return _median(_clean(values));
  }

  List<PriceSource> _prioritizedSources(List<PriceSource> input) {
    final q = query.text.toLowerCase();
    final electronics = RegExp(
      r'(iphone|ipad|macbook|samsung|galaxy|pixel|smartphone|handy|tablet|laptop|notebook|playstation|ps5|xbox|switch|kamera|objektiv|kopfh[oö]rer|airpods|watch)',
    ).hasMatch(q);
    final fashion = RegExp(
      r'(sneaker|schuh|nike|adidas|jordan|yeezy|jacke|hose|shirt|kleid|pulli|pullover|mode|tasche|gucci|prada|vuitton)',
    ).hasMatch(q);

    final order = fashion
        ? <String>['vinted', 'kleinanzeigen', 'ebay_de', 'idealo', 'geizhals', 'amazon_de', 'backmarket', 'rebuy', 'mediamarkt', 'saturn']
        : electronics
            ? <String>['kleinanzeigen', 'ebay_de', 'rebuy', 'backmarket', 'geizhals', 'idealo', 'amazon_de', 'mediamarkt', 'saturn', 'vinted']
            : <String>['ebay_de', 'kleinanzeigen', 'vinted', 'idealo', 'geizhals', 'amazon_de', 'rebuy', 'backmarket', 'mediamarkt', 'saturn'];
    final rank = <String, int>{for (var i = 0; i < order.length; i++) order[i]: i};
    final original = <String, int>{for (var i = 0; i < input.length; i++) input[i].id: i};
    final sorted = [...input];
    sorted.sort((a, b) {
      final ar = rank[a.id] ?? 999;
      final br = rank[b.id] ?? 999;
      if (ar != br) return ar.compareTo(br);
      return (original[a.id] ?? 999).compareTo(original[b.id] ?? 999);
    });
    return sorted;
  }

  double? get targetSell {
""",
)

# Remove eBay-only affordance from the app bar. Comparison is now neutral and
# visible in the main flow.
replace_once(
    'lib/v10_app.dart',
    """      appBar: AppBar(
        title: Text(t('Deal-Check', 'Deal check'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: t('Echte eBay-Verkäufe', 'eBay sold listings'),
            onPressed: query.text.trim().isEmpty ? null : _openEbaySold,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
""",
    """      appBar: AppBar(
        title: Text(t('Deal-Check', 'Deal check'), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
""",
)

replace_once(
    'lib/v10_app.dart',
    """    final enabled = widget.sources.where((s) => s.enabled).toList();
    final enteringManualSell = showManual && _manualSellCommitted == null;

    return Scaffold(
""",
    """    final enabled = _prioritizedSources(widget.sources.where((s) => s.enabled).toList());
    final enteringManualSell = showManual && _manualSellCommitted == null;
    final sourcePrices = <String, double>{};
    for (final source in enabled) {
      final value = _sourceMedian(source.id);
      if (value != null) sourcePrices[source.id] = value;
    }

    return Scaffold(
""",
)

replace_once(
    'lib/v10_app.dart',
    """                _MissingValueCard(
                  english: widget.english,
                  retail: retailMedian,
                  onEbaySold: _openEbaySold,
                ),
""",
    """                _MissingValueCard(
                  english: widget.english,
                  retail: retailMedian,
                ),
""",
)

# Make manual price entry shorter and keep the big action hidden until it can
# actually be used.
replace_once(
    'lib/v10_app.dart',
    """                  labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                  hintText: 'z. B. 250',
                  helperText: t('Erst mit ✓ oder „Übernehmen“ bestätigen.', 'Confirm with ✓ or “Apply”.'),
""",
    """                  labelText: t('Verkaufspreis selbst eintragen', 'Enter sale price yourself'),
                  hintText: 'z. B. 250',
                  helperText: t('Komplett eintippen, dann ✓.', 'Type the full amount, then ✓.'),
""",
)

replace_once(
    'lib/v10_app.dart',
    """              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('commit-manual-sale-price'),
                  onPressed: _value(manualSell) > 0 ? _commitManualSell : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t('VERKAUFSPREIS ÜBERNEHMEN', 'APPLY SALE PRICE')),
                ),
              ),
""",
    """              if (_value(manualSell) > 0) ...[
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('commit-manual-sale-price'),
                    onPressed: _commitManualSell,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t('PREIS ÜBERNEHMEN', 'APPLY PRICE')),
                  ),
                ),
              ],
""",
)

# Put every enabled comparison portal in the main flow, before Details.
replace_once(
    'lib/v10_app.dart',
    """            ],
            const SizedBox(height: 10),
            ExpansionTile(
""",
    """            ],
            const SizedBox(height: 14),
            _QuickCompareSection(
              english: widget.english,
              sources: enabled,
              sourcePrices: sourcePrices,
              onEbaySold: _openEbaySold,
              onOpenSource: _openSource,
            ),
            const SizedBox(height: 10),
            ExpansionTile(
""",
)

# Remove the duplicated portal controls from Details, which is now for numbers
# and raw listings only.
replace_once(
    'lib/v10_app.dart',
    """                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openEbaySold,
                    icon: const Icon(Icons.history_rounded),
                    label: Text(t('eBay: VERKAUFTE ARTIKEL PRÜFEN', 'eBay: CHECK SOLD ITEMS')),
                  ),
                ),
""",
    """                const SizedBox(height: 8),
""",
)

replace_once(
    'lib/v10_app.dart',
    """                if (enabled.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: enabled.take(8).map((s) => SourcePillButton(source: s, onTap: () => _openSource(s))).toList(),
                    ),
                  ),
                ],
""",
    """""",
)

replace_once(
    'lib/v10_app.dart',
    """                    'Aktive Angebote sind keine bestätigten Verkäufe. FlipRadar nutzt deshalb 10 % Sicherheitsabstand. Für echte Verkäufe nutze den eBay-Button oben.',
                    'Active listings are not confirmed sales. FlipRadar applies a 10% safety margin. Use the eBay button above to inspect sold items.',
""",
    """                    'Aktive Angebote sind keine bestätigten Verkäufe. FlipRadar nutzt deshalb 10 % Sicherheitsabstand. Für echte Verkäufe nutze oben „eBay verkauft“.',
                    'Active listings are not confirmed sales. FlipRadar applies a 10% safety margin. For real sales, use “eBay sold” above.',
""",
)

# Replace the eBay-heavy missing-value card with a neutral explanation and add
# a compact, always-visible comparison grid.
old_missing = """class _MissingValueCard extends StatelessWidget {
  final bool english;
  final double? retail;
  final VoidCallback onEbaySold;

  const _MissingValueCard({required this.english, required this.retail, required this.onEbaySold});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF2D5), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('MARKTWERT NOCH NICHT SICHER', 'MARKET VALUE NOT CLEAR YET'), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6A4B00))),
          if (retail != null) ...[
            const SizedBox(height: 4),
            Text(t('Neupreis-Referenz: ${euro(retail!)}', 'Retail reference: ${euro(retail!)}'), style: const TextStyle(fontSize: 12, color: Color(0xFF7C632B))),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onEbaySold,
              icon: const Icon(Icons.history_rounded),
              label: Text(t('VERKAUFTE EBAY-ARTIKEL ANSEHEN', 'VIEW SOLD EBAY ITEMS')),
            ),
          ),
        ],
      ),
    );
  }
}

"""
new_missing = """class _MissingValueCard extends StatelessWidget {
  final bool english;
  final double? retail;

  const _MissingValueCard({required this.english, required this.retail});

  @override
  Widget build(BuildContext context) {
    String t(String de, String en) => english ? en : de;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF2D5), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('MARKTWERT NOCH NICHT SICHER', 'MARKET VALUE NOT CLEAR YET'), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6A4B00))),
          if (retail != null) ...[
            const SizedBox(height: 4),
            Text(t('Neupreis-Referenz: ${euro(retail!)}', 'Retail reference: ${euro(retail!)}'), style: const TextStyle(fontSize: 12, color: Color(0xFF7C632B))),
          ],
          const SizedBox(height: 5),
          Text(
            t('Unten kurz eine Quelle prüfen – oder den Verkaufspreis selbst eintragen.', 'Check a source below or enter the sale price yourself.'),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C632B), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _QuickCompareSection extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final Map<String, double> sourcePrices;
  final VoidCallback onEbaySold;
  final ValueChanged<PriceSource> onOpenSource;

  const _QuickCompareSection({
    required this.english,
    required this.sources,
    required this.sourcePrices,
    required this.onEbaySold,
    required this.onOpenSource,
  });

  String t(String de, String en) => english ? en : de;

  String _purpose(PriceSource source) {
    if (source.id == 'idealo' || source.id == 'geizhals') return t('PREISVERGLEICH', 'PRICE CHECK');
    switch (source.role) {
      case 'resale':
        return t('ANGEBOTE', 'LISTINGS');
      case 'local':
        return source.id == 'vinted' ? t('SECONDHAND', 'SECONDHAND') : t('LOKAL', 'LOCAL');
      case 'retail':
        return t('NEUPREIS', 'RETAIL');
      case 'buyback':
        return t('SOFORTANKAUF', 'BUYBACK');
      case 'refurb':
        return t('REFURBISHED', 'REFURBISHED');
      default:
        return t('VERGLEICH', 'COMPARE');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: Color(0xFF4E50D8)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('WO WILLST DU VERGLEICHEN?', 'WHERE DO YOU WANT TO CHECK?'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    Text(t('Passende Quellen zuerst · einfach antippen', 'Best matches first · just tap'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF777B88))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 330 ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
              final cards = <Widget>[
                _QuickPortalCard(
                  width: cardWidth,
                  name: t('eBay verkauft', 'eBay sold'),
                  purpose: t('VERKAUFT', 'SOLD'),
                  icon: Icons.history_rounded,
                  color: const Color(0xFF3665F3),
                  onTap: onEbaySold,
                ),
                ...sources.map(
                  (source) => _QuickPortalCard(
                    width: cardWidth,
                    name: source.name,
                    purpose: _purpose(source),
                    icon: sourceIcon(source.id),
                    color: sourceColor(source),
                    price: sourcePrices[source.id],
                    onTap: () => onOpenSource(source),
                  ),
                ),
              ];
              return Wrap(spacing: 8, runSpacing: 8, children: cards);
            },
          ),
        ],
      ),
    );
  }
}

class _QuickPortalCard extends StatelessWidget {
  final double width;
  final String name;
  final String purpose;
  final IconData icon;
  final Color color;
  final double? price;
  final VoidCallback onTap;

  const _QuickPortalCard({
    required this.width,
    required this.name,
    required this.purpose,
    required this.icon,
    required this.color,
    required this.onTap,
    this.price,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: color.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(99)),
                              child: Text(purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
                            ),
                          ),
                          if (price != null) ...[
                            const SizedBox(width: 5),
                            Flexible(child: Text('≈ ${euro(price!)}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF8A8E9B)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

"""
replace_once('lib/v10_app.dart', old_missing, new_missing)

# Regression test: comparison portals must be visible without opening Details.
test_path = Path('test/v10_flow_test.dart')
test = test_path.read_text()
needle = "\n}\n"
idx = test.rfind(needle)
if idx < 0:
    raise RuntimeError('test/v10_flow_test.dart: could not find suite closing brace')
new_test = r'''
  testWidgets('V0.11 shows comparison portals before Details is opened', (tester) async {
    const sources = <PriceSource>[
      PriceSource(
        id: 'kleinanzeigen',
        name: 'Kleinanzeigen',
        subtitle: 'Lokal',
        searchUrlTemplate: 'https://www.kleinanzeigen.de/s-{query}/k0',
        role: 'local',
        colorHex: '00A98F',
      ),
      PriceSource(
        id: 'amazon_de',
        name: 'Amazon DE',
        subtitle: 'Neu',
        searchUrlTemplate: 'https://www.amazon.de/s?k={query}',
        role: 'retail',
        colorHex: 'FF9900',
      ),
      PriceSource(
        id: 'vinted',
        name: 'Vinted',
        subtitle: 'Secondhand',
        searchUrlTemplate: 'https://www.vinted.de/catalog?search_text={query}',
        role: 'local',
        colorHex: '007782',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: FastCheckPage(
          english: false,
          initialQuery: 'Samsung Fold 8',
          targetRoi: 35,
          plan: UserPlan.free,
          sources: sources,
          onHistory: (_) {},
          onWatch: (_) {},
          onAddFlip: (_) {},
          onRemoveFlip: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WO WILLST DU VERGLEICHEN?'), findsOneWidget);
    expect(find.text('eBay verkauft'), findsOneWidget);
    expect(find.text('Kleinanzeigen'), findsOneWidget);
    expect(find.text('Amazon DE'), findsOneWidget);
    expect(find.text('Vinted'), findsOneWidget);
    expect(find.text('Zusatzkosten gesamt'), findsNothing);
  });
'''
test = test[:idx] + '\n' + new_test + test[idx:]
test_path.write_text(test)

# Built-in registry test for the two new direct-search sources.
registry_test_path = Path('test/source_registry_test.dart')
registry_test = registry_test_path.read_text()
idx = registry_test.rfind('\n}')
if idx < 0:
    raise RuntimeError('test/source_registry_test.dart: could not find suite closing brace')
registry_add = r'''
  test('German quick-compare sources include Vinted and Geizhals', () {
    final sources = SourceRegistry.builtIns();
    final vinted = sources.singleWhere((s) => s.id == 'vinted');
    final geizhals = sources.singleWhere((s) => s.id == 'geizhals');
    expect(vinted.searchUrl('Nike Dunk'), contains('search_text=Nike%20Dunk'));
    expect(vinted.canFetchInApp, isFalse);
    expect(geizhals.searchUrl('Galaxy S26'), contains('fs=Galaxy%20S26'));
    expect(geizhals.canFetchInApp, isFalse);
  });
'''
registry_test_path.write_text(registry_test[:idx] + '\n' + registry_add + registry_test[idx:])

print('FlipRadar V0.11 patch applied.')
