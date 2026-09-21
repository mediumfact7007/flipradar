import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String _checkedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return _de
        ? 'Preis geprüft: $day.$month. · $hour:$minute Uhr'
        : 'Price checked: $month/$day · $hour:$minute local time';
  }

  // Keep the final user action behind the same trust gate as the comparison.
  // This is intentionally stricter than checking only scheme/host so a card
  // can never open a low-confidence, malformed or non-public provider target
  // even if a summary is constructed outside the normal filtered pipeline.
  bool get _hasSafeOfferUrl => summary.offer.isEligibleForComparison;

  Future<void> _openOffer() async {
    if (!_hasSafeOfferUrl) return;
    await launchUrl(summary.offer.offerUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final marginDifference = summary.instantMargin - summary.privateMargin;
    final instantBetter = marginDifference > 0;
    final equalProfit = marginDifference.abs() < 0.01;
    final noProfitableExit = summary.instantMargin <= 0 && summary.privateMargin <= 0;
    final theme = Theme.of(context);
    final recommendation = noProfitableExit
        ? (_de ? 'Kein positiver Exit – Einkaufspreis zu hoch' : 'No profitable exit – purchase price is too high')
        : equalProfit
            ? (_de ? 'Gleicher Gewinn – Sofortankauf spart Zeit' : 'Same profit – instant buyback saves time')
            : instantBetter
                ? (_de
                    ? 'Sofortankauf: ${_money(marginDifference)} mehr Gewinn'
                    : 'Instant buyback: ${_money(marginDifference)} more profit')
                : (_de
                    ? 'Privatverkauf: ${_money(-marginDifference)} mehr Gewinn'
                    : 'Private sale: ${_money(-marginDifference)} more profit');

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
                color: noProfitableExit ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    noProfitableExit ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
                    size: 16,
                    color: noProfitableExit ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: noProfitableExit ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
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
              emphasized: !noProfitableExit && !instantBetter && !equalProfit,
              emphasisLabel: _de ? 'Mehr Erlös' : 'Higher payout',
            ),
            const Divider(height: 22),
            _ExitRow(
              title: _de ? 'Sofortankauf' : 'Instant buyback',
              value: _money(summary.offer.price),
              detail: '${summary.offer.providerName} · ${_de ? 'Gewinn' : 'Profit'} ${_money(summary.instantMargin)} · ROI ${_roi(summary.instantRoi)}',
              emphasized: !noProfitableExit && instantBetter,
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
              _checkedAt(summary.offer.checkedAt),
              key: const ValueKey('buyback-checked-at'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _de
                  ? 'Privatwert = aktueller FlipRadar-Marktwert. Ankauf = frisches, qualitätsgefiltertes Anbieterangebot.'
                  : 'Private value = current FlipRadar market value. Buyback = fresh, quality-filtered provider offer.',
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('buyback-open-offer'),
                onPressed: _hasSafeOfferUrl ? _openOffer : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(
                  _hasSafeOfferUrl
                      ? (_de ? 'Angebot bei ${summary.offer.providerName} öffnen' : 'Open offer at ${summary.offer.providerName}')
                      : (_de ? 'Angebotslink nicht verfügbar' : 'Offer link unavailable'),
                ),
              ),
            ),
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
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
