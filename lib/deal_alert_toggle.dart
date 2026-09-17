import 'package:flutter/material.dart';

import 'deal_alert.dart';
import 'deal_alert_store.dart';

/// Compact opt-in control for saved-deal alerts.
///
/// The control is intentionally local-only for now: it persists the user's
/// preference without requesting notification permissions or depending on a
/// push provider. That keeps the watchlist useful today and leaves delivery
/// infrastructure isolated for a later step.
class DealAlertToggle extends StatefulWidget {
  final String flipId;
  final bool english;
  final DealAlertStore? store;

  const DealAlertToggle({
    super.key,
    required this.flipId,
    required this.english,
    this.store,
  });

  @override
  State<DealAlertToggle> createState() => _DealAlertToggleState();
}

class _DealAlertToggleState extends State<DealAlertToggle> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  DealAlertPreference? _preference;
  bool _loading = true;
  bool _saving = false;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DealAlertToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipId != widget.flipId) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final preference = await _store.forFlip(widget.flipId);
    if (!mounted) return;
    setState(() {
      _preference = preference;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final next = (_preference ?? DealAlertPreference.defaults(widget.flipId))
        .copyWith(enabled: enabled, updatedAt: DateTime.now());
    final saved = await _store.save(next);
    if (!mounted) return;
    setState(() {
      if (saved) _preference = next;
      _saving = false;
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Deal-Alarm konnte nicht gespeichert werden.', 'Deal alert could not be saved.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _preference?.enabled ?? false;
    final busy = _loading || _saving;
    return Container(
      key: ValueKey('deal-alert-${widget.flipId}'),
      padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF2F7F4) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? const Color(0x22087F5B) : const Color(0xFFE9EAF0)),
      ),
      child: Row(children: [
        Icon(
          enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          size: 19,
          color: enabled ? const Color(0xFF087F5B) : const Color(0xFF777B88),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Deal-Alarm', 'Deal alert'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
          Text(
            enabled
                ? t('Markiert beim Recheck Verbesserungen ab +5 € Gewinn oder +5 %-Pkt. ROI.', 'Flags recheck improvements from +€5 profit or +5pp ROI.')
                : t('Beim Recheck deutlich bessere Deals markieren.', 'Flag meaningfully better deals on recheck.'),
            style: const TextStyle(fontSize: 9.8, color: Color(0xFF707481)),
          ),
          if (enabled)
            Text(
              t('Aktuell lokal in FlipRadar – keine Push-Nachricht.', 'Currently local in FlipRadar — no push notification.'),
              style: const TextStyle(fontSize: 9.2, color: Color(0xFF8B8E9A)),
            ),
        ])),
        Switch.adaptive(
          key: ValueKey('deal-alert-switch-${widget.flipId}'),
          value: enabled,
          onChanged: busy ? null : _setEnabled,
        ),
      ]),
    );
  }
}
