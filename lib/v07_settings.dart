part of 'v07.dart';

class SettingsPage extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final UserPlan plan;
  final List<PriceSource> sources;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<String> onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlanPreview;
  final ValueChanged<List<PriceSource>> onSources;

  const SettingsPage({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.plan,
    required this.sources,
    required this.onLanguage,
    required this.onBackend,
    required this.onRoi,
    required this.onPlanPreview,
    required this.onSources,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double roi;
  late bool english;

  String t(String de, String en) => english ? en : de;

  @override
  void initState() {
    super.initState();
    roi = widget.targetRoi;
    english = widget.english;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.sources.where((s) => s.enabled).length;
    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).length;

    return Scaffold(
      appBar: AppBar(title: Text(t('Einstellungen', 'Settings'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(t('Dein Gewinnziel', 'Your profit target'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(t('FlipRadar berechnet danach deinen maximalen Einkaufspreis.', 'FlipRadar uses this to calculate your maximum buy price.'), style: const TextStyle(color: Color(0xFF777B89), fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEDEDFC), borderRadius: BorderRadius.circular(22)),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(t('Mindest-ROI', 'Minimum ROI'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${roi.toStringAsFixed(0)} %', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4B4CB8))),
                  ],
                ),
                Slider(
                  value: roi.clamp(10, 100),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${roi.toStringAsFixed(0)} %',
                  onChanged: (v) => setState(() => roi = v),
                  onChangeEnd: widget.onRoi,
                ),
                Wrap(
                  spacing: 7,
                  children: [25.0, 35.0, 50.0].map((v) {
                    return ChoiceChip(
                      label: Text(v == 25 ? t('25 % locker', '25% light') : v == 35 ? t('35 % standard', '35% standard') : t('50 % hoch', '50% high')),
                      selected: (roi - v).abs() < 1,
                      onSelected: (_) {
                        setState(() => roi = v);
                        widget.onRoi(v);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFE8F8F2), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF0A8F6A)),
              ),
              title: Text(t('$enabled Quellen aktiv', '$enabled sources enabled'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(t('$direct können Live-Daten direkt in FlipRadar liefern', '$direct can provide live data inside FlipRadar'), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SourcesPage(
                      english: english,
                      sources: widget.sources,
                      onChanged: widget.onSources,
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(t('Sprache', 'Language'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Deutsch')),
              ButtonSegment(value: true, label: Text('English')),
            ],
            selected: {english},
            onSelectionChanged: (value) {
              setState(() => english = value.first);
              widget.onLanguage(value.first);
            },
          ),
          const SizedBox(height: 22),
          _PremiumCard(english: english, plan: widget.plan),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(t('Erweitert', 'Advanced'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(t('Nur für Tests und Entwickler', 'For testing and developers only'), style: const TextStyle(fontSize: 12)),
            children: [
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.backend,
                decoration: InputDecoration(
                  labelText: t('Eigene Server-Adresse', 'Custom server URL'),
                  hintText: SourceRegistry.defaultBackend,
                ),
                onFieldSubmitted: widget.onBackend,
              ),
              const SizedBox(height: 12),
              Text(t('Tarif-Vorschau', 'Plan preview'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SegmentedButton<UserPlan>(
                segments: const [
                  ButtonSegment(value: UserPlan.free, label: Text('FREE')),
                  ButtonSegment(value: UserPlan.pro, label: Text('PRO')),
                  ButtonSegment(value: UserPlan.proPlus, label: Text('PRO+')),
                ],
                selected: {widget.plan},
                onSelectionChanged: (v) => widget.onPlanPreview(v.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final bool english;
  final UserPlan plan;

  const _PremiumCard({required this.english, required this.plan});

  @override
  Widget build(BuildContext context) {
    final active = plan != UserPlan.free;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF272650), Color(0xFF5B5CE2)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? (english ? 'Premium active' : 'Premium aktiv') : 'FlipRadar PRO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 3),
                Text(
                  english ? 'No ads · more live checks · price alerts' : 'Keine Werbung · mehr Live-Checks · Preisalarme',
                  style: const TextStyle(color: Color(0xFFD3D3EE), fontSize: 12),
                ),
              ],
            ),
          ),
          if (!active)
            TinyLabel(text: english ? 'SOON' : 'BALD', color: const Color(0xFF403F82), background: Colors.white),
        ],
      ),
    );
  }
}

class SourcesPage extends StatefulWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;

  const SourcesPage({
    super.key,
    required this.english,
    required this.sources,
    required this.onChanged,
  });

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  late List<PriceSource> items;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
  }

  void commit() {
    widget.onChanged([...items]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2C6A9F)),
                const SizedBox(width: 10),
                Expanded(child: Text(t('Einfach einschalten, wo FlipRadar suchen soll.', 'Simply enable where FlipRadar should search.'), style: const TextStyle(color: Color(0xFF355F80), fontSize: 13, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final source = entry.value;
            final c = sourceColor(source);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
                      child: Icon(sourceIcon(source.id), color: c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                              const SizedBox(width: 6),
                              TinyLabel(
                                text: source.canFetchInApp ? 'LIVE' : 'WEB',
                                color: source.canFetchInApp ? const Color(0xFF0A8F6A) : const Color(0xFF727684),
                                background: source.canFetchInApp ? const Color(0xFFE8F8F2) : const Color(0xFFF0F1F5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            source.canFetchInApp
                                ? t('Direkt in FlipRadar möglich', 'Can work inside FlipRadar')
                                : t('Öffnet die echte Webseite', 'Opens the real website'),
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF7B7F8D)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: source.enabled,
                      onChanged: (v) {
                        setState(() => items[i] = source.copyWith(enabled: v));
                        commit();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(t('Eigene Quelle hinzufügen', 'Add your own source'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(t('Für Shops oder Partner', 'For shops or partners'), style: const TextStyle(fontSize: 12)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addSimpleWebsite,
                      icon: const Icon(Icons.add_link_rounded),
                      label: Text(t('Webseite', 'Website')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importManifest,
                      icon: const Icon(Icons.integration_instructions_outlined),
                      label: Text(t('Partner-Link', 'Partner link')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addSimpleWebsite() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final result = await showDialog<PriceSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Webseite hinzufügen', 'Add website')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: t('Name', 'Name'))),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              decoration: InputDecoration(
                labelText: t('Such-Link', 'Search URL'),
                hintText: 'https://shop.de/search?q={query}',
              ),
            ),
            const SizedBox(height: 8),
            Text(t('{query} wird automatisch durch den Suchbegriff ersetzt.', '{query} is replaced by the search term.'), style: const TextStyle(fontSize: 11, color: Color(0xFF7B7F8D))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Abbrechen', 'Cancel'))),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || !url.text.contains('{query}')) return;
              Navigator.pop(
                context,
                PriceSource(
                  id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                  name: name.text.trim(),
                  subtitle: t('Eigene Webseite', 'Custom website'),
                  searchUrlTemplate: url.text.trim(),
                  builtIn: false,
                  recommended: false,
                  enabled: true,
                ),
              );
            },
            child: Text(t('Hinzufügen', 'Add')),
          ),
        ],
      ),
    );
    name.dispose();
    url.dispose();
    if (result != null && mounted) {
      setState(() => items.add(result));
      commit();
    }
  }

  Future<void> _importManifest() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Partner-Link einfügen', 'Paste partner link')),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://…/flipradar-source.json')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Abbrechen', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(t('Importieren', 'Import'))),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    try {
      final source = await SourceRegistry.importManifest(url);
      if (!mounted) return;
      setState(() => items.add(source));
      commit();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Quelle hinzugefügt.', 'Source added.'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Partner-Link konnte nicht geladen werden.', 'Could not load partner link.'))));
    }
  }
}
