import 'package:flutter/material.dart';

import 'deal_alert.dart';
import 'deal_alert_store.dart';

/// Shows a saved deal's local alert result directly in the recheck flow.
/// Disabled/missing preferences stay silent so the normal check UI is unchanged.
class DealAlertResultCard extends StatefulWidget {
  final String flipId;
  final bool english;
  final double previousProfit;
  final double currentProfit;
  final double previousRoi;
  final double currentRoi;
  final DealAlertStore? store;

  const DealAlertResultCard({
    super.key,
    required this.flipId,
    required this.english,
    required this.previousProfit,
    required this.currentProfit,
    required this.previousRoi,
    required this.currentRoi,
    this.store,
  });

  @override
  State<DealAlertResultCard> createState() => _DealAlertResultCardState();
}

class _DealAlertResultCardState extends State<DealAlertResultCard> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  DealAlertPreference? _preference;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DealAlertResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipId != widget.flipId) {
      setState(() => _preference = null);
      _load();
    }
  }

  Future<void> _load() async {
    final requestedFlipId = widget.flipId;
    final preference = await _store.forFlip(requestedFlipId);
    if (!mounted || requestedFlipId != widget.flipId) return;
    setState(() => _preference = preference);
  }

  @override
  Widget build(BuildContext context) {
    final preference = _preference;
    if (preference == null || !preference.enabled) return const SizedBox.shrink();
    final evaluation = evaluateDealAlert(
      preference: preference,
      previousProfit: widget.previousProfit,
      currentProfit: widget.currentProfit,
      previousRoi: widget.previousRoi,
      currentRoi: widget.currentRoi,
    );
    if (!evaluation.triggered) return const SizedBox.shrink();

    final reasons = <String>[];
    if (evaluation.becameProfitable) {
      reasons.add(t('Jetzt profitabel', 'Now profitable'));
    }
    if (evaluation.profitThresholdReached) {
      reasons.add('${t('Gewinn', 'Profit')} +${evaluation.profitIncrease.toStringAsFixed(0)} €');
    }
    if (evaluation.roiThresholdReached) {
      reasons.add('ROI +${evaluation.roiIncrease.toStringAsFixed(0)} %-Pkt');
    }
    final comparison =
        '${t('Vorher', 'Before')}: ${t('Gewinn', 'Profit')} ${widget.previousProfit.toStringAsFixed(0)} € · ROI ${widget.previousRoi.toStringAsFixed(0)} %\n'
        '${t('Jetzt', 'Now')}: ${t('Gewinn', 'Profit')} ${widget.currentProfit.toStringAsFixed(0)} € · ROI ${widget.currentRoi.toStringAsFixed(0)} %';
    final threshold =
        '${t('Dein Alarm', 'Your alert')}: +${preference.minProfitIncrease.toStringAsFixed(0)} € ${t('Gewinn', 'profit')} ${t('oder', 'or')} +${preference.minRoiIncrease.toStringAsFixed(0)} %-Pkt. ROI';

    return Container(
      key: const ValueKey('v153-deal-alert-result'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33087F5B)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.notifications_active_rounded, color: Color(0xFF087F5B), size: 21),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('DEAL-ALARM AUSGELÖST', 'DEAL ALERT TRIGGERED'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF087F5B))),
          const SizedBox(height: 4),
          Text(reasons.join(' · '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(comparison, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.35, color: Color(0xFF34413C))),
          const SizedBox(height: 4),
          Text(threshold, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF52605A))),
          const SizedBox(height: 3),
          Text(t('Seit deinem letzten gespeicherten Check deutlich besser.', 'Meaningfully better than your last saved check.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF626B67))),
          const SizedBox(height: 2),
          Text(t('Lokaler Recheck-Hinweis – aktuell keine Push-Nachricht.', 'Local recheck notice — currently no push notification.'), style: const TextStyle(fontSize: 9.8, color: Color(0xFF7B837F))),
        ])),
      ]),
    );
  }
}
