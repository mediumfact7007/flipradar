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

    return Card(
      key: const ValueKey('buyback-comparison-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _de ? 'Wie willst du verkaufen?' : 'How do you want to sell?',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _de
                  ? 'Vergleiche mehr Erlös mit einem schnellen, planbaren Verkauf.'
                  : 'Compare more upside with a fast, predictable sale.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _ExitRow(
              title: _de ? 'Privat verkaufen' : 'Sell privately',
              value: _money(summary.privateMarketValue),
              detail: '${_de ? 'Gewinn' : 'Profit'} ${_money(summary.privateMargin)} · ROI ${_roi(summary.privateRoi)}',
              emphasized: !instantBetter,
            ),
            const Divider(height: 22),
            _ExitRow(
              title: _de ? 'Sofortankauf' : 'Instant buyback',
              value: _money(summary.offer.price),
              detail: '${summary.offer.providerName} · ${_de ? 'Gewinn' : 'Profit'} ${_money(summary.instantMargin)} · ROI ${_roi(summary.instantRoi)}',
              emphasized: instantBetter,
            ),
            if (summary.convenienceGap > 0) ...[
              const SizedBox(height: 12),
              Text(
                _de
                    ? 'Für den schnelleren Verkauf verzichtest du auf ca. ${_money(summary.convenienceGap)} möglichen Erlös.'
                    : 'The faster sale gives up about ${_money(summary.convenienceGap)} of potential upside.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (summary.offer.requiresInspection) ...[
              const SizedBox(height: 6),
              Text(
                _de
                    ? 'Ankaufspreis vorbehaltlich Prüfung durch den Anbieter.'
                    : 'Buyback price is subject to provider inspection.',
                style: theme.textTheme.bodySmall,
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
  });

  final String title;
  final String value;
  final String detail;
  final bool emphasized;

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
