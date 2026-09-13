import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V0.13.6 keeps breathing room below the target hint', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.13.6+22'));
    expect(app, contains("Ziel: ${r'${widget.targetRoi.toStringAsFixed(0)}'} % ROI + mindestens ${r'${v13Euro(widget.minProfit)}'} Gewinn."));

    final hint = app.indexOf("Ziel: ${r'${widget.targetRoi.toStringAsFixed(0)}'} % ROI");
    expect(hint, greaterThanOrEqualTo(0));
    final afterHint = app.substring(hint, (hint + 900).clamp(0, app.length));
    expect(afterHint, contains('const SizedBox(height: 14)'));
  });
}
