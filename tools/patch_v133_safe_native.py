from pathlib import Path

p = Path('lib/v13_app.dart')
text = p.read_text()

old = """class V13SearchInput {
  final String raw;
  final String query;
  final V13InputKind kind;
  final String? correction;

  const V13SearchInput({required this.raw, required this.query, required this.kind, this.correction});
}
"""
new = """class V13SearchInput {
  final String raw;
  final String query;
  final V13InputKind kind;
  final String? correction;
  final double? detectedPrice;

  const V13SearchInput({required this.raw, required this.query, required this.kind, this.correction, this.detectedPrice});
}
"""
if old not in text:
    raise SystemExit('V13SearchInput marker not found')
text = text.replace(old, new, 1)

marker = "V13SearchInput normalizeV13Search(String rawInput) {"
helper = r'''double? _detectSharedPrice(String raw) {
  final lines = raw.replaceAll('\u00a0', ' ').split(RegExp(r'[\r\n]+'));
  final pattern = RegExp(r'(\d{1,6}(?:[. ]\d{3})*(?:[,.]\d{1,2})?)\s*(?:€|EUR)\b', caseSensitive: false);
  double? fallback;
  for (final line in lines) {
    final lower = line.toLowerCase();
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final value = v13Money(match.group(1)!);
    if (value < 2 || value > 100000) continue;
    if (RegExp(r'\b(versand|porto|shipping)\b').hasMatch(lower)) {
      fallback ??= value;
      continue;
    }
    return value;
  }
  return fallback;
}

'''
if helper.strip() not in text:
    if marker not in text:
        raise SystemExit('normalize marker not found')
    text = text.replace(marker, helper + marker, 1)

start = text.index('V13SearchInput normalizeV13Search(String rawInput) {')
end = text.index('\nString v13Category(', start)
segment = text[start:end]
segment = segment.replace(
    "  if (raw.isEmpty) return const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);\n",
    "  if (raw.isEmpty) return const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);\n  final detectedPrice = _detectSharedPrice(raw);\n",
    1,
)
segment = segment.replace('raw: raw,', 'raw: raw, detectedPrice: detectedPrice,')
text = text[:start] + segment + text[end:]

old_share = '        unawaited(_openCheck(normalized.query));'
if old_share in text:
    text = text.replace(old_share, '        unawaited(_openCheck(item.path));', 1)

old_init = """    query = TextEditingController(text: widget.input.query);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
"""
new_init = """    query = TextEditingController(text: widget.input.query);
    final detected = widget.input.detectedPrice;
    if (detected != null && detected > 0) {
      buy.text = detected == detected.roundToDouble()
          ? detected.toStringAsFixed(0)
          : detected.toStringAsFixed(2).replaceAll('.', ',');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
"""
if old_init not in text:
    raise SystemExit('check init marker not found')
text = text.replace(old_init, new_init, 1)

old_base = """    final median = activeMedian;
    if (median == null || median <= 0) return null;
    // Asking-price heuristic only; deliberately not labelled as sold data.
    return median * .90;
"""
new_base = """    final values = resaleValues;
    if (values.length < 3) return null;
    final median = _median(values);
    if (median == null || median <= 0) return null;
    // Asking-price heuristic only; deliberately not labelled as sold data.
    return median * .90;
"""
if old_base not in text:
    raise SystemExit('base expected sale marker not found')
text = text.replace(old_base, new_base, 1)

buy_field = """          TextField(
            key: const ValueKey('v13-buy-input'),
            controller: buy,
            focusNode: buyFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('Was sollst du zahlen?', 'What would you pay?'), hintText: '0,00', suffixText: '€', prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded)),
          ),
"""
buy_field_new = buy_field + """          if (widget.input.detectedPrice != null) ...[
            const SizedBox(height: 4),
            Text(t('Angebotspreis automatisch erkannt – kurz prüfen und bei Bedarf ändern.', 'Listing price detected automatically – quickly verify and edit if needed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483))),
          ],
"""
if buy_field not in text:
    raise SystemExit('buy field marker not found')
text = text.replace(buy_field, buy_field_new, 1)

call_old = """            profit: profit,
            roi: roi,
            speed: personal.speedLabel(widget.english),
"""
call_new = """            profit: profit,
            roi: roi,
            buyPrice: buyPrice,
            speed: personal.speedLabel(widget.english),
"""
if call_old not in text:
    raise SystemExit('decision call marker not found')
text = text.replace(call_old, call_new, 1)

field_old = """  final double profit;
  final double roi;
  final String speed;
"""
field_new = """  final double profit;
  final double roi;
  final double buyPrice;
  final String speed;
"""
if field_old not in text:
    raise SystemExit('decision field marker not found')
text = text.replace(field_old, field_new, 1)

ctor_old = "const _V13DecisionCard({required this.english, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onBought, this.onNegotiate});"
ctor_new = "const _V13DecisionCard({required this.english, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.buyPrice, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onBought, this.onNegotiate});"
if ctor_old not in text:
    raise SystemExit('decision constructor marker not found')
text = text.replace(ctor_old, ctor_new, 1)

metrics = """          const SizedBox(height: 7),
          Text(t('Ziel: ≥ ${targetRoi.toStringAsFixed(0)} % ROI und ≥ ${v13Euro(minProfit)} Gewinn · Datenqualität $confidence.', 'Target: ≥ ${targetRoi.toStringAsFixed(0)}% ROI and ≥ ${v13Euro(minProfit)} profit · data quality $confidence.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF686C79))),
"""
metrics_new = """          const SizedBox(height: 7),
          if (maxBuy != null && buyPrice > 0)
            Text(
              buyPrice <= maxBuy!
                  ? t('${v13Euro(maxBuy! - buyPrice)} Puffer bis zu deinem MAX.', '${v13Euro(maxBuy! - buyPrice)} buffer below your MAX.')
                  : t('${v13Euro(buyPrice - maxBuy!)} über deinem MAX.', '${v13Euro(buyPrice - maxBuy!)} above your MAX.'),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color),
            ),
          const SizedBox(height: 3),
          Text(t('Ziel: ≥ ${targetRoi.toStringAsFixed(0)} % ROI und ≥ ${v13Euro(minProfit)} Gewinn · Datenqualität $confidence.', 'Target: ≥ ${targetRoi.toStringAsFixed(0)}% ROI and ≥ ${v13Euro(minProfit)} profit · data quality $confidence.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF686C79))),
"""
if metrics not in text:
    raise SystemExit('decision metrics marker not found')
text = text.replace(metrics, metrics_new, 1)

p.write_text(text)
print('SAFE UX continuation patch applied')
