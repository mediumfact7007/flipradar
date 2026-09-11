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

    return Scaffold(
      appBar: AppBar(title: Text(t('Einstellungen', 'Settings'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _SettingsSectionTitle(title: t('Dein Gewinnziel', 'Your profit target'), subtitle: t('Bestimmt, wie günstig du einkaufen solltest.', 'Defines how cheaply you should buy.')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEDEDFC), borderRadius: BorderRadius.circular(22)),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(t('Mindest-Rendite', 'Minimum return'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text('${roi.toStringAsFixed(0)} %', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF4B4CB8))),
                  ],
                ),
                Slider(
                  value: roi.clamp(10, 100),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  onChanged: (v) => setState(() => roi = v),
                  onChangeEnd: widget.onRoi,
                ),
                Row(
                  children: [25.0, 35.0, 50.0].map((v) {
                    final selected = (roi - v).abs() < 1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Center(child: Text(v == 25 ? t('Locker', 'Light') : v == 35 ? t('Standard', 'Standard') : t('Hoch', 'High'))),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => roi = v);
                            widget.onRoi(v);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SettingsSectionTitle(title: t('Preisquellen', 'Price sources'), subtitle: t('Wo FlipRadar Preise prüft.', 'Where FlipRadar checks prices.')),
          const SizedBox(height: 9),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFE8F8F2), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront_outlined, color: Color(0xFF0A8F6A)),
              ),
              title: Text(t('$enabled Quellen aktiv', '$enabled sources enabled'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(t('Antippen zum Ein-/Ausschalten', 'Tap to enable or disable'), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SourcesPage(english: english, sources: widget.sources, onChanged: widget.onSources),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 22),
          _SettingsSectionTitle(title: t('Sprache', 'Language')),
          const SizedBox(height: 9),
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
            leading: const Icon(Icons.build_outlined),
            title: Text(t('Für Profis & Entwickler', 'For pros & developers'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(t('Im Alltag nicht nötig', 'Not needed for normal use'), style: const TextStyle(fontSize: 12)),
            children: [
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.backend,
                decoration: InputDecoration(labelText: t('Eigener Server', 'Custom server'), hintText: SourceRegistry.defaultBackend),
                onFieldSubmitted: widget.onBackend,
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text(t('Tarif testen', 'Preview plan'), style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(height: 7),
              SegmentedButton<UserPlan>(
                segments: const [
                  ButtonSegment(value: UserPlan.free, label: Text('FREE')),
                  ButtonSegment(value: UserPlan.pro, label: Text('PRO')),
                ],
                selected: {widget.plan == UserPlan.proPlus ? UserPlan.pro : widget.plan},
                onSelectionChanged: (v) => widget.onPlanPreview(v.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SettingsSectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: const TextStyle(color: Color(0xFF777B89), fontSize: 12.5)),
        ],
      ],
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
                Text(active ? (english ? 'PRO active' : 'PRO aktiv') : 'FlipRadar PRO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 3),
                Text(english ? 'No ads · more checks · price alerts' : 'Keine Werbung · mehr Checks · Preisalarme', style: const TextStyle(color: Color(0xFFD3D3EE), fontSize: 12)),
              ],
            ),
          ),
          if (!active) TinyLabel(text: english ? 'SOON' : 'BALD', color: const Color(0xFF403F82), background: Colors.white),
        ],
      ),
    );
  }
}

class SourcesPage extends StatefulWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;

  const SourcesPage({super.key, required this.english, required this.sources, required this.onChanged});

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

  void commit() => widget.onChanged([...items]);

  String roleText(String role) {
    switch (role) {
      case 'resale':
        return t('Wiederverkauf', 'Resale');
      case 'local':
        return t('Lokal', 'Local');
      case 'retail':
        return t('Neupreis', 'Retail');
      case 'refurb':
        return 'Refurbished';
      case 'buyback':
        return t('Sofort-Ankauf', 'Buyback');
      default:
        return t('Referenz', 'Reference');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(t('Nur einschalten, wo du vergleichen möchtest.', 'Only enable where you want to compare.'), style: const TextStyle(fontSize: 13, color: Color(0xFF6F7482))),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final source = entry.value;
            final c = sourceColor(source);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
                      child: Icon(sourceIcon(source.id), color: c, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('${roleText(source.role)} · ${source.canFetchInApp ? 'LIVE' : 'WEB'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF7B7F8D))),
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
            leading: const Icon(Icons.integration_instructions_outlined),
            title: Text(t('Partner / eigene Quelle', 'Partner / custom source'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(t('Nur wenn du eine weitere Webseite anbinden willst', 'Only to add another website'), style: const TextStyle(fontSize: 12)),
            children: [
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _addSimpleWebsite, icon: const Icon(Icons.add_link_rounded), label: Text(t('Webseite', 'Website')))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: _importManifest, icon: const Icon(Icons.code_rounded), label: Text(t('Partner-Link', 'Partner link')))),
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
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Such-Link', hintText: 'https://shop.de/search?q={query}')),
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
                  role: 'reference',
                  builtIn: false,
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
        title: Text(t('Partner-Link', 'Partner link')),
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
      setState(() {
        items.removeWhere((x) => x.id == source.id);
        items.add(source);
      });
      commit();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Quelle hinzugefügt.', 'Source added.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Import fehlgeschlagen.', 'Import failed.'))));
    }
  }
}
