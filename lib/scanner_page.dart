import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum UserPlan { free, pro, proPlus }

class ScannerPage extends StatefulWidget {
  final bool english;
  const ScannerPage({super.key, required this.english});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool handled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.english ? 'Scan barcode' : 'Barcode scannen')),
    body: Stack(fit: StackFit.expand, children: [
      MobileScanner(onDetect: (capture) {
        if (handled) return;
        final code = capture.barcodes.firstOrNull?.rawValue;
        if (code == null || code.isEmpty) return;
        handled = true;
        Navigator.pop(context, code);
      }),
      IgnorePointer(child: Center(child: Container(width: 270, height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24))))),
      Positioned(left: 24, right: 24, bottom: 34, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(18)),
        child: Text(widget.english ? 'Hold the barcode inside the frame.' : 'Barcode einfach in den Rahmen halten.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      )),
    ]),
  );
}
