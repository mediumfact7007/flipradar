part of 'v06.dart';

class ScannerPage extends StatefulWidget {
  final bool english;
  const ScannerPage({super.key, required this.english});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false;
  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Barcode scannen', 'Scan barcode'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (done) return;
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value == null || value.isEmpty) return;
              done = true;
              Navigator.pop(context, value);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)),
              child: Text(
                t('Barcode in den Rahmen halten – FlipRadar übernimmt den Rest.', 'Hold the barcode inside the frame – FlipRadar handles the rest.'),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SponsoredCard extends StatelessWidget {
  final bool english;
  final String messageDe;
  final String messageEn;

  const SponsoredCard({
    super.key,
    required this.english,
    required this.messageDe,
    required this.messageEn,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: english ? 'Sponsored advertising placeholder' : 'Werbeplatzhalter',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.campaign_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(english ? 'Sponsored' : 'Werbung', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  const SizedBox(height: 3),
                  Text(english ? messageEn : messageDe, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SponsoredStrip extends StatelessWidget {
  final bool english;
  const SponsoredStrip({super.key, required this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Text(english ? 'Sponsored' : 'Werbung', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(width: 10),
          Expanded(child: Text(english ? 'Compact partner placement' : 'Kompakter Partnerplatz')),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool current;
  final bool highlight;
  final List<String> bullets;

  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.current,
    required this.bullets,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? Theme.of(context).colorScheme.primaryContainer.withOpacity(.45) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current ? Theme.of(context).colorScheme.primary : Colors.black12, width: current ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  if (current) ...[
                    const SizedBox(width: 6),
                    const Chip(label: Text('AKTIV'), visualDensity: VisualDensity.compact),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...bullets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [const Icon(Icons.check, size: 16), const SizedBox(width: 6), Expanded(child: Text(b))]),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget header(String title, String subtitle) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );

Widget sectionTitle(BuildContext context, String text) => Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );

Widget infoBox(BuildContext context, IconData icon, String text) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );

Widget smallMetric(String label, String value, IconData icon) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );

Widget howRow(String number, IconData icon, String title, String subtitle) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 16, child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

Widget resultTile(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );

Widget sourceBadge(PriceSource source) {
  final color = colorFromHex(source.colorHex);
  return CircleAvatar(
    backgroundColor: color.withOpacity(.12),
    child: Text(source.name.isEmpty ? '?' : source.name.substring(0, 1).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
  );
}

Widget planChip(UserPlan plan) {
  final text = plan == UserPlan.free ? 'FREE' : plan == UserPlan.pro ? 'PRO' : 'PRO+';
  return Chip(label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)));
}

Color colorFromHex(String hex) {
  try {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return const Color(0xFF5146E5);
  }
}

String statusLabel(String status, bool english) {
  if (english) return status;
  switch (status) {
    case 'Bought':
      return 'Gekauft';
    case 'Listed':
      return 'Inseriert';
    case 'Sold':
      return 'Verkauft';
    default:
      return status;
  }
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
