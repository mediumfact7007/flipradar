part of 'v07.dart';

String euro(double value, {int digits = 0}) => '${value.toStringAsFixed(digits)} €';

Color sourceColor(PriceSource source) {
  final raw = source.colorHex.replaceAll('#', '');
  final value = int.tryParse(raw, radix: 16) ?? 0x5B5CE2;
  return Color(0xFF000000 | value);
}

IconData sourceIcon(String id) {
  switch (id) {
    case 'ebay_de':
      return Icons.sell_outlined;
    case 'kleinanzeigen':
      return Icons.location_on_outlined;
    case 'amazon_de':
      return Icons.shopping_bag_outlined;
    case 'mediamarkt':
    case 'saturn':
      return Icons.devices_outlined;
    case 'idealo':
      return Icons.compare_arrows;
    case 'rebuy':
    case 'backmarket':
      return Icons.recycling_outlined;
    default:
      return Icons.storefront_outlined;
  }
}

Widget screenHeader(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.7),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6D7180), fontSize: 14)),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}

class TinyLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const TinyLabel({super.key, required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? background;

  const MetricBox({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF636779)),
            const SizedBox(height: 8),
          ],
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF777B89), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SponsoredSlot extends StatelessWidget {
  final bool english;
  final String placement;

  const SponsoredSlot({super.key, required this.english, this.placement = 'feed'});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E4EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_outlined, color: Color(0xFF818594)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  english ? 'Ad space' : 'Werbefläche',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5D6170)),
                ),
                const SizedBox(height: 2),
                Text(
                  english ? 'Reserved for a calm native ad.' : 'Reserviert für eine dezente native Anzeige.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8E9C)),
                ),
              ],
            ),
          ),
          TinyLabel(
            text: english ? 'AD' : 'ANZEIGE',
            color: const Color(0xFF777B89),
            background: Colors.white,
          ),
        ],
      ),
    );
  }
}

class SourcePillButton extends StatelessWidget {
  final PriceSource source;
  final VoidCallback onTap;

  const SourcePillButton({super.key, required this.source, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = sourceColor(source);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sourceIcon(source.id), size: 17, color: c),
            const SizedBox(width: 7),
            Text(source.name, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 13, color: Color(0xFF7A7E8C)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF777B89), height: 1.4)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  final bool english;

  const ScannerPage({super.key, required this.english});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.english ? 'Scan barcode' : 'Barcode scannen'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (handled) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code == null || code.isEmpty) return;
              handled = true;
              Navigator.pop(context, code);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 270,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(18)),
              child: Text(
                widget.english ? 'Hold the barcode inside the frame.' : 'Barcode einfach in den Rahmen halten.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
