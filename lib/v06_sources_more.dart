part of 'v06.dart';

class SourcesPage extends StatefulWidget {
  final bool english;
  final String backend;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;

  const SourcesPage({
    super.key,
    required this.english,
    required this.backend,
    required this.sources,
    required this.onChanged,
  });

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  late List<PriceSource> local;
  bool importing = false;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    local = [...widget.sources];
  }

  void save() {
    widget.onChanged(local);
    SourceRegistry.save(local);
  }

  Future<void> addCustom() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final result = await showDialog<PriceSource>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Eigene Website hinzufügen', 'Add your own website')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: t('Name', 'Name'))),
            const SizedBox(height: 8),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'Such-Link mit {query}',
                hintText: 'https://shop.de/search?q={query}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('Abbrechen', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              final u = url.text.trim();
              if (n.isEmpty || !u.contains('{query}')) return;
              Navigator.pop(
                c,
                PriceSource(
                  id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                  name: n,
                  subtitle: t('Eigene Quelle · offizielle Suche', 'Custom source · official search'),
                  searchUrlTemplate: u,
                  enabled: true,
                  builtIn: false,
                  colorHex: '5146E5',
                ),
              );
            },
            child: Text(t('Hinzufügen', 'Add')),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => local.add(result));
      save();
    }
  }

  Future<void> importManifest() async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Partner-Quelle importieren', 'Import partner source')),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: t('Manifest-Link', 'Manifest URL'),
            hintText: 'https://partner.de/flipradar-source.json',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Abbrechen', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(t('Importieren', 'Import'))),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;

    setState(() => importing = true);
    try {
      final source = await SourceRegistry.importManifest(value);
      if (!mounted) return;
      setState(() {
        local.removeWhere((s) => s.id == source.id);
        local.add(source);
      });
      save();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Quelle hinzugefügt', 'Source added'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('Import fehlgeschlagen', 'Import failed')}: $e')));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final built = local.where((e) => e.builtIn).toList();
    final custom = local.where((e) => !e.builtIn).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t('Preisquellen', 'Price sources'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          infoBox(
            context,
            Icons.touch_app_outlined,
            t(
              'Einfach einschalten, was du nutzt. „Direkt live“ bedeutet: Preis erscheint in FlipRadar. „Website“ öffnet die offizielle Suche.',
              'Just enable what you use. “Live in app” means the price appears inside FlipRadar. “Website” opens the official search.',
            ),
          ),
          const SizedBox(height: 14),
          ...built.map((s) => SourceSwitchTile(
                source: s,
                english: widget.english,
                onChanged: (v) {
                  final i = local.indexWhere((x) => x.id == s.id);
                  setState(() => local[i] = local[i].copyWith(enabled: v));
                  save();
                },
              )),
          if (custom.isNotEmpty) ...[
            const SizedBox(height: 16),
            sectionTitle(context, t('Eigene & Partner-Quellen', 'Custom & partner sources')),
            const SizedBox(height: 8),
            ...custom.map((s) => SourceSwitchTile(
                  source: s,
                  english: widget.english,
                  onChanged: (v) {
                    final i = local.indexWhere((x) => x.id == s.id);
                    setState(() => local[i] = local[i].copyWith(enabled: v));
                    save();
                  },
                  onDelete: () {
                    setState(() => local.removeWhere((x) => x.id == s.id));
                    save();
                  },
                )),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: addCustom,
            icon: const Icon(Icons.add_link),
            label: Text(t('Eigene Website hinzufügen', 'Add your own website')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: importing ? null : importManifest,
            icon: importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.extension_outlined),
            label: Text(t('Partner-Quelle importieren', 'Import partner source')),
          ),
          const SizedBox(height: 12),
          infoBox(
            context,
            widget.backend.trim().isEmpty ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            widget.backend.trim().isEmpty
                ? t('Direkte Live-APIs sind noch nicht mit deinem FlipRadar-Server verbunden.', 'Direct live APIs are not connected to your FlipRadar server yet.')
                : t('FlipRadar-Server ist hinterlegt. Unterstützte Quellen liefern automatisch Live-Treffer.', 'FlipRadar server is configured. Supported sources automatically provide live results.'),
          ),
        ],
      ),
    );
  }
}

class SourceSwitchTile extends StatelessWidget {
  final PriceSource source;
  final bool english;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  const SourceSwitchTile({
    super.key,
    required this.source,
    required this.english,
    required this.onChanged,
    this.onDelete,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          leading: sourceBadge(source),
          title: Row(
            children: [
              Flexible(child: Text(source.name, style: const TextStyle(fontWeight: FontWeight.w800))),
              if (source.recommended) ...[
                const SizedBox(width: 6),
                Chip(label: Text(t('Empfohlen', 'Recommended')), visualDensity: VisualDensity.compact),
              ],
            ],
          ),
          subtitle: Text(source.canFetchInApp ? t('Direkt live in FlipRadar', 'Live inside FlipRadar') : t('Offizielle Website-Suche', 'Official website search')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onDelete != null) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              Switch(value: source.enabled, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final UserPlan plan;
  final int sourceCount;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<String> onBackend;
  final ValueChanged<double> onRoi;
  final ValueChanged<UserPlan> onPlanPreview;
  final VoidCallback onSources;

  const MorePage({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.plan,
    required this.sourceCount,
    required this.onLanguage,
    required this.onBackend,
    required this.onRoi,
    required this.onPlanPreview,
    required this.onSources,
  });

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header(t('Mehr', 'More'), t('Tarif, Quellen und einfache Einstellungen.', 'Plan, sources and simple settings.')),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.hub_outlined)),
            title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(t('$sourceCount Quellen aktiv', '$sourceCount sources enabled')),
            trailing: const Icon(Icons.chevron_right),
            onTap: onSources,
          ),
        ),
        const SizedBox(height: 14),
        sectionTitle(context, t('Premium', 'Premium')),
        const SizedBox(height: 8),
        PlanCard(
          title: 'FREE',
          price: '0 €',
          current: plan == UserPlan.free,
          bullets: [
            t('Grundlegende Preisprüfung', 'Basic price checks'),
            t('Barcode & Flips', 'Barcode & flips'),
            t('Ruhige Werbeplätze', 'Calm ad placements'),
          ],
        ),
        const SizedBox(height: 8),
        PlanCard(
          title: 'PRO',
          price: '9,99 € / Monat',
          current: plan == UserPlan.pro,
          highlight: true,
          bullets: [
            t('Werbefrei', 'Ad-free'),
            t('Automatische Preisalarme', 'Automatic price alerts'),
            t('Mehr Live-Checks & Statistiken', 'More live checks & statistics'),
          ],
        ),
        const SizedBox(height: 8),
        PlanCard(
          title: 'PRO+',
          price: '19,99 € / Monat',
          current: plan == UserPlan.proPlus,
          bullets: [
            t('Alles aus PRO', 'Everything in PRO'),
            t('Eigene/Partner-Integrationen', 'Custom/partner integrations'),
            t('Cross-Border & erweiterte Exporte', 'Cross-border & advanced exports'),
          ],
        ),
        const SizedBox(height: 10),
        infoBox(
          context,
          Icons.info_outline,
          t(
            'Testversion: noch keine echte Zahlung. Unten kannst du nur die Tarif-Oberfläche testen.',
            'Test build: no real payment yet. Below you can only preview the plan experience.',
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<UserPlan>(
          segments: const [
            ButtonSegment(value: UserPlan.free, label: Text('FREE')),
            ButtonSegment(value: UserPlan.pro, label: Text('PRO')),
            ButtonSegment(value: UserPlan.proPlus, label: Text('PRO+')),
          ],
          selected: {plan},
          onSelectionChanged: (v) => onPlanPreview(v.first),
        ),
        const SizedBox(height: 18),
        sectionTitle(context, t('Einstellungen', 'Settings')),
        SwitchListTile(
          value: english,
          onChanged: onLanguage,
          title: Text(t('Englisch verwenden', 'Use English')),
          secondary: const Icon(Icons.language),
        ),
        ListTile(
          leading: const Icon(Icons.percent),
          title: Text(t('Ziel-ROI', 'Target ROI')),
          subtitle: Text('${targetRoi.toStringAsFixed(0)} %'),
        ),
        Slider(
          value: targetRoi.clamp(10, 100),
          min: 10,
          max: 100,
          divisions: 18,
          label: '${targetRoi.toStringAsFixed(0)} %',
          onChanged: onRoi,
        ),
        ExpansionTile(
          leading: const Icon(Icons.settings_ethernet),
          title: Text(t('Erweitert: FlipRadar-Server', 'Advanced: FlipRadar server')),
          subtitle: Text(backend.trim().isEmpty ? t('Noch nicht verbunden', 'Not connected') : backend),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _BackendEditor(initial: backend, english: english, onSave: onBackend),
            ),
          ],
        ),
        const SizedBox(height: 12),
        infoBox(
          context,
          Icons.ads_click_outlined,
          t(
            'Werbestrategie: FREE nutzt wenige native/kompakte Plätze an ruhigen Stellen. Keine Überraschungs-Werbung beim Scannen oder Lesen der Kaufentscheidung. PRO/PRO+ bleibt werbefrei.',
            'Ad strategy: FREE uses a few native/compact placements at calm moments. No surprise ads while scanning or reading the buy decision. PRO/PRO+ stays ad-free.',
          ),
        ),
      ],
    );
  }
}

class _BackendEditor extends StatefulWidget {
  final String initial;
  final bool english;
  final ValueChanged<String> onSave;

  const _BackendEditor({required this.initial, required this.english, required this.onSave});

  @override
  State<_BackendEditor> createState() => _BackendEditorState();
}

class _BackendEditorState extends State<_BackendEditor> {
  late final TextEditingController c;

  @override
  void initState() {
    super.initState();
    c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = (String de, String en) => widget.english ? en : de;
    return Column(
      children: [
        TextField(
          controller: c,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: t('Server-Adresse', 'Server URL'),
            hintText: 'https://api.flipradar.app',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => widget.onSave(c.text.trim()),
            child: Text(t('Speichern', 'Save')),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('API-Schlüssel gehören auf den Server – nicht in die App.', 'API keys belong on the server – not inside the app.'),
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}
