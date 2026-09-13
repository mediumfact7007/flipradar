import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release version never regresses below the validated V0.14.8 baseline', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true).firstMatch(text);
    expect(match, isNotNull, reason: 'pubspec.yaml must contain one Flutter version line');

    final major = int.parse(match!.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final build = int.parse(match.group(4)!);

    final semantic = major * 1000000 + minor * 1000 + patch;
    const minimumSemantic = 0 * 1000000 + 14 * 1000 + 8;

    expect(semantic, greaterThanOrEqualTo(minimumSemantic));
    expect(build, greaterThanOrEqualTo(31), reason: 'Android versionCode/build number must never move backwards');
  });
}
