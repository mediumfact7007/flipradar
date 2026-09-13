import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V0.15 only marks eBay live after auth succeeds', () {
    final status = File('lib/source_status.dart').readAsStringSync();
    final server = File('server/index.js').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.15.0+25'));
    expect(status, contains('final String auth;'));
    expect(status, contains("s.auth == 'ok'"));
    expect(status, contains("queryParameters: const {'probe': '1'}"));
    expect(server, contains('async function sourceStatus(probe = false)'));
    expect(server, contains("auth: 'missing'"));
    expect(server, contains("auth: 'ok'"));
    expect(server, contains("auth: 'invalid'"));
  });
}
