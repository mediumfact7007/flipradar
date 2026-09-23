import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback.dart';

/// Current provider quotes stay visible even when no private-market valuation
/// exists. The caller supplies already validated, condition-matched offers.
class BuybackOffersCard extends StatelessWidget {
  const BuybackOffersCard({super.key, required this.offers, required this.purchasePrice, this.english = false});

  final List<BuybackOffer> offers;
  final double purchasePrice;
  final bool english;

  String _money(double amount) => '${amount.toStringAsFixed(2).replaceAll('.', english ? '.' : ',')} €';

  String _checkedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return english ? '$month/$day $hour:$minute' : '$day.$month. $hour:$minute Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final ranked = offers.where((offer) => offer.isEligibleForComparison).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    if (ranked.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('buyback-offers-card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(english ? 'Current buyback offers' : 'Aktuelle Ankaufangebote', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(english ? 'Indicative prices for the selected condition; inspection may change the payout.' : 'Vorläufige Preise für den gewählten Zustand; die Prüfung kann den Auszahlungsbetrag ändern.', style: theme.textTheme.bodySmall),
          for (final offer in ranked) ...[
            const Divider(height: 20),
            Row(
              key: ValueKey('buyback-offer-${offer.providerId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(offer.providerName, style: theme.textTheme.titleSmall),
                  Text(offer.matchedTitle, style: theme.textTheme.bodySmall),
                  Text(
                    english ? 'Checked: ${_checkedAt(offer.checkedAt)} · Match ${(offer.matchConfidence * 100).round()}%' : 'Geprüft: ${_checkedAt(offer.checkedAt)} · Treffer ${(offer.matchConfidence * 100).round()} %',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (purchasePrice > 0)
                    Text(
                      english ? 'Profit after purchase: ${_money(offer.price - purchasePrice)}' : 'Gewinn nach Einkauf: ${_money(offer.price - purchasePrice)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_money(offer.price), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => launchUrl(offer.offerUrl, mode: LaunchMode.externalApplication),
                    child: Text(english ? 'Open' : 'Öffnen'),
                  ),
                ]),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}
