import 'package:flutter/material.dart';

import 'recheck_delta.dart';

class RecheckDeltaCard extends StatelessWidget {
  final bool english;
  final RecheckDelta delta;

  const RecheckDeltaCard({super.key, required this.english, required this.delta});

  String t(String de, String en) => english ? en : de;

  String money(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)} €';
  }

  String points(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)} %-Pkt';
  }

  @override
  Widget build(BuildContext context) {
    final improved = delta.improved;
    final worsened = delta.worsened;
    final accent = improved
        ? const Color(0xFF087F5B)
        : worsened
            ? const Color(0xFFC33A46)
            : const Color(0xFF6D7180);
    final title = improved
        ? t('DEAL BESSER GEWORDEN', 'DEAL IMPROVED')
        : worsened
            ? t('DEAL SCHLECHTER GEWORDEN', 'DEAL WORSENED')
            : t('DEAL FAST UNVERÄNDERT', 'DEAL ABOUT THE SAME');
    final icon = improved
        ? Icons.trending_up_rounded
        : worsened
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Container(
      key: const ValueKey('v149-recheck-delta'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DeltaChip(
                label: '${t('Preis', 'Price')} ${money(delta.askingDelta)}',
                positive: delta.askingDelta <= 0,
              ),
              _DeltaChip(
                label: 'MAX ${money(delta.maxBuyDelta)}',
                positive: delta.maxBuyDelta >= 0,
              ),
              _DeltaChip(
                label: '${t('Gewinn', 'Profit')} ${money(delta.profitDelta)}',
                positive: delta.profitDelta >= 0,
              ),
              _DeltaChip(
                label: 'ROI ${points(delta.roiDelta)}',
                positive: delta.roiDelta >= 0,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            t(
              'Vergleich mit deinem letzten gespeicherten Check.',
              'Compared with your last saved check.',
            ),
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483)),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final bool positive;

  const _DeltaChip({required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    final foreground = positive ? const Color(0xFF087F5B) : const Color(0xFFC33A46);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: foreground)),
    );
  }
}
