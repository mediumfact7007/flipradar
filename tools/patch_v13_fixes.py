from pathlib import Path

p = Path('lib/v13_app.dart')
text = p.read_text()

text = text.replace("import 'package:flutter/foundation.dart';\n", '')
text = text.replace("  final Set<String> finished = {};\n", '')
text = text.replace("      finished.clear();\n", '')
text = text.replace("    finished.add(source.id);\n", '')
text = text.replace("  DateTime openedAt = DateTime.now();\n", '')
text = text.replace("      openedAt = DateTime.now();\n", '')

text = text.replace(
"""class _V13SettingsPageState extends State<V13SettingsPage> {
  late double roi = widget.targetRoi;
  late double minProfit = widget.minProfit;
  late bool english = widget.english;
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) => Scaffold(
""",
"""class _V13SettingsPageState extends State<V13SettingsPage> {
  late double roi;
  late double minProfit;
  late bool english;
  String t(String de, String en) => english ? en : de;

  @override
  void initState() {
    super.initState();
    roi = widget.targetRoi;
    minProfit = widget.minProfit;
    english = widget.english;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
""",
)

text = text.replace(
"""class _V13SourcesPageState extends State<V13SourcesPage> {
  late List<PriceSource> items = [...widget.sources];
  String t(String de, String en) => widget.english ? en : de;
  @override
""",
"""class _V13SourcesPageState extends State<V13SourcesPage> {
  late List<PriceSource> items;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
  }

  @override
""",
)

# Flutter 3.47 prefers initialValue on DropdownButtonFormField.
text = text.replace("DropdownButtonFormField<String>(value: platform,", "DropdownButtonFormField<String>(initialValue: platform,")
text = text.replace("DropdownButtonFormField<V13TaxMode>(value: widget.taxMode,", "DropdownButtonFormField<V13TaxMode>(initialValue: widget.taxMode,")

# Do not let unavailable platform channels break tests or sideloaded builds.
text = text.replace(
"""  Future<void> init() async {
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_purchaseUpdate, onError: (_) {});
    unawaited(_initBilling());
    unawaited(_initAds());
  }
""",
"""  Future<void> init() async {
    try {
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_purchaseUpdate, onError: (_) {});
    } catch (_) {}
    unawaited(_initBilling());
    unawaited(_initAds());
  }
""",
)

# Only mount AdWidget after Google reports the banner as loaded.
text = text.replace(
"""class _V13BannerAdState extends State<V13BannerAd> {
  BannerAd? ad;
  bool failed = false;
""",
"""class _V13BannerAdState extends State<V13BannerAd> {
  BannerAd? ad;
  bool loaded = false;
  bool failed = false;
""",
)
text = text.replace(
"""    final next = BannerAd(size: AdSize.banner, adUnitId: widget.monetization.bannerId, listener: BannerAdListener(onAdLoaded: (_) { if (mounted) setState(() {}); }, onAdFailedToLoad: (value, error) { value.dispose(); failed = true; if (mounted) setState(() {}); }), request: const AdRequest());
""",
"""    final next = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.monetization.bannerId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          loaded = true;
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (value, error) {
          value.dispose();
          ad = null;
          failed = true;
          loaded = false;
          if (mounted) setState(() {});
        },
      ),
      request: const AdRequest(),
    );
""",
)
text = text.replace(
"""    if (current == null) return const SizedBox.shrink();
""",
"""    if (current == null || !loaded) return const SizedBox.shrink();
""",
)

p.write_text(text)
print('V0.13 cleanup patch applied')
