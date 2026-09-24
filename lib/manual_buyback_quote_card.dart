import 'package:flutter/material.dart';

class ManualBuybackQuote {
  const ManualBuybackQuote({
    required this.providerName,
    required this.price,
  });

  final String providerName;
  final double price;
}

class ManualBuybackQuoteCard extends StatefulWidget {
  const ManualBuybackQuoteCard({
    super.key,
    required this.purchasePrice,
    required this.conditionLabel,
    required this.onChanged,
    this.privateMarketValue,
    this.initialQuote,
    this.english = false,
  });

  final double purchasePrice;
  final double? privateMarketValue;
  final String conditionLabel;
  final ManualBuybackQuote? initialQuote;
  final ValueChanged<ManualBuybackQuote?> onChanged;
  final bool english;

  @override
  State<ManualBuybackQuoteCard> createState() => _ManualBuybackQuoteCardState();
}

class _ManualBuybackQuoteCardState extends State<ManualBuybackQuoteCard> {
  static const providers = ['reBuy', 'ZOXS', 'Clevertronic'];

  late final TextEditingController price;
  late String provider;
  ManualBuybackQuote? committed;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuote;
    provider = providers.contains(initial?.providerName)
        ? initial!.providerName
        : providers.first;
    committed = initial;
    price = TextEditingController(
      text: initial == null ? '' : initial.price.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  double _parsePrice(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[^0-9,.]'), '');
    if (value.contains(',') && value.contains('.')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      value = value.replaceAll(',', '.');
    }
    return double.tryParse(value) ?? 0;
  }

  String _money(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', widget.english ? '.' : ',')} €';

  void _apply() {
    final amount = _parsePrice(price.text);
    if (!amount.isFinite || amount <= 0 || amount > 10000) return;
    final quote = ManualBuybackQuote(providerName: provider, price: amount);
    setState(() => committed = quote);
    widget.onChanged(quote);
    FocusScope.of(context).unfocus();
  }

  void _clear() {
    price.clear();
    setState(() => committed = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final quote = committed;
    final instantProfit = quote == null || widget.purchasePrice <= 0
        ? null
        : quote.price - widget.purchasePrice;
    final privateValue = widget.privateMarketValue;
    final resultHeadline = quote == null
        ? ''
        : instantProfit == null
            ? '${quote.providerName}: ${_money(quote.price)}'
            : '${quote.providerName}: ${_money(quote.price)} · ${t('Gewinn', 'profit')}: ${_money(instantProfit)}';
    return Card(
      key: const ValueKey('manual-buyback-quote-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.edit_note_rounded, size: 19),
            const SizedBox(width: 7),
            Expanded(child: Text(t('Anbieterpreis manuell übernehmen', 'Enter provider price manually'), style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(
            t(
              'Trage nur einen Preis ein, den du selbst beim Anbieter für „${widget.conditionLabel}“ gesehen hast. Diese Angabe wird lokal verglichen und ist kein von Flipwert geprüfter LIVE-Preis.',
              'Only enter a price you saw yourself at the provider for “${widget.conditionLabel}”. It is compared locally and is not a LIVE price verified by Flipwert.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 9),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const ValueKey('manual-buyback-provider'),
                initialValue: provider,
                decoration: InputDecoration(labelText: t('Anbieter', 'Provider')),
                items: providers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => provider = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('manual-buyback-price'),
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(labelText: t('Ankaufpreis', 'Buyback price'), suffixText: '€'),
              ),
            ),
          ]),
          const SizedBox(height: 7),
          Row(children: [
            FilledButton.icon(
              key: const ValueKey('manual-buyback-apply'),
              onPressed: _apply,
              icon: const Icon(Icons.calculate_outlined, size: 17),
              label: Text(t('Vergleichen', 'Compare')),
            ),
            if (quote != null) ...[
              const SizedBox(width: 7),
              TextButton(onPressed: _clear, child: Text(t('Entfernen', 'Remove'))),
            ],
          ]),
          if (quote != null) ...[
            const Divider(height: 18),
            Container(
              key: const ValueKey('manual-buyback-result'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D79A)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  resultHeadline,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (instantProfit == null)
                  Text(
                    t('Einkaufspreis eintragen, um den Gewinn zu berechnen.', 'Enter the purchase price to calculate profit.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (privateValue != null && privateValue > 0)
                  Text(
                    privateValue >= quote.price
                        ? t('Privatverkauf liegt ${_money(privateValue - quote.price)} höher.', 'Private sale is ${_money(privateValue - quote.price)} higher.')
                        : t('Manueller Anbieterpreis liegt ${_money(quote.price - privateValue)} höher.', 'Manual provider price is ${_money(quote.price - privateValue)} higher.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  t('Manuelle Nutzerangabe · nicht LIVE geprüft', 'Manual user entry · not LIVE verified'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF9A6700)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }
}
