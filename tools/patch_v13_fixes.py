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

p.write_text(text)
print('V0.13 cleanup patch applied')
