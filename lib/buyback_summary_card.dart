import 'package:flutter/material.dart';

import 'buyback_summary.dart';

/// Compact, user-facing decision card for the two realistic exit paths.
///
/// The card deliberately consumes an already trusted summary instead of raw
/// provider payloads, keeping market-quality filtering outside the widget.
class BuybackComparisonCard extends StatelessWidget {
  const BuybackComparisonCard({
    super.key,
    required this.summary,
    this.locale = 'de',
  });

  final BuybackComparisonSummary summary;
  final String locale;

  bool get _de => locale.toLowerCase().startsWith('de');

  String _money(double value) => '${value.toStringAsFixed(0)} €';
  String _roi(double value) => '${value.toStringAsFixed(0)} %';

  @override
  Widget build(BuildContext context) {
    final instantBetter = summary.instantMargin >= summary.privateMargin;
    final theme = Theme.of(context);
    final recommendation = instantBetter
        ? (_de ? 'Sofortankauf bringt hier mehr' : 'Instant buyback pays more here')
        : (_de ? 'Privatverkauf bringt mehr' : 'Private sale pays more');

    return Card(
      key: const ValueKey('buyback-comparison-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _de ? 'Privat oder sofort verkaufen?' : 'Sell privately or instantly?',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _de
                  ? 'FlipRadar zeigt dir Erlös, Gewinn und den Preis für mehr Bequemlichkeit.'
                  : 'FlipRadar shows proceeds, profit and the price of extra convenience.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('buyback-recommendation'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ExitRow(
              title: _de ? 'Privat verkaufen' : 'Sell privately',
              value: _money(summary.privateMarketValue),
              detail: '${_de ? 'Gewinn' : 'Profit'} ${_money(summary.privateMargin)} · ROI ${_roi(summary.privateRoi)}',
              emphasized: !instantBetter,
              emphasisLabel: _de ? 'Mehr Erlös' : 'Higher payout',
            ),
            const Divider(height: 22),
            _ExitRow(
              title: _de ? 'Sofortankauf' : 'Instant buyback',
              value: _money(summary.offer.price),
              detail: '${summary.offer.providerName} · ${_de ? 'Gewinn' : 'Profit'} ${_money(summary.instantMargin)} · ROI ${_roi(summary.instantRoi)}',
              emphasized: instantBetter,
              emphasisLabel: _de ? 'Mehr Erlös' : 'Higher payout',
            ),
            if (summary.convenienceGap > 0) ...[
              const SizedBox(height: 12),
              Text(
                _de
                    ? 'Zeit-vs.-Geld: Sofortankauf kostet dich hier ca. ${_money(summary.convenienceGap)} möglichen Erlös.'
                    : 'Time vs money: instant buyback costs about ${_money(summary.convenienceGap)} in potential proceeds here.',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              _de
                  ? 'Privatwert = aktueller FlipRadar-Marktwert. Ankauf = verifiziertes, frisches Anbieterangebot.'
                  : 'Private value = current FlipRadar market value. Buyback = verified, fresh provider offer.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (summary.offer.requiresInspection) ...[
              const SizedBox(height: 6),
              Text(
                _de
                    ? 'Wichtig: Der endgültige Ankaufspreis kann sich nach Prüfung durch den Anbieter ändern.'
                    : 'Important: the final buyback price may change after provider inspection.',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({
    required this.title,
    required this.value,
    required this.detail,
    required this.emphasized,
    required this.emphasisLabel,
  });

  final String title;
  final String value;
  final String detail;
  final bool emphasized;
  final String emphasisLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
                  if (emphasized) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, size: 17, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        emphasisLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
