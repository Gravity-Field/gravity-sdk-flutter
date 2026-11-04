import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_sdk/src/data/error_reporting/diagnostic_url_sanitizer.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

const authorizationLineVectors = <(String, String)>[
  ('authorization: [Bearer SECRET]', 'authorization: [redacted]'),
  ('Authorization: Token SECRET', 'Authorization: [redacted]'),
  ('Proxy-Authorization: Bearer SECRET', 'Proxy-Authorization: [redacted]'),
  ('x-authorization: SECRET', 'x-authorization: [redacted]'),
  (
    'Authorization: Bearer SECRET\nnext line',
    'Authorization: [redacted]\nnext line',
  ),
  (
    'PROXY-AUTHORIZATION=Token SECRET\r\nnext line',
    'PROXY-AUTHORIZATION: [redacted]\r\nnext line',
  ),
  (
    'before X-Authorization = [Token SECRET] after',
    'before X-Authorization: [redacted]',
  ),
  ('Authorization:\nnext line', 'Authorization: [redacted]\nnext line'),
  (
    'Authorization: SECRET\nAuthorization=SECRET',
    'Authorization: [redacted]\nAuthorization: [redacted]',
  ),
];

void main() {
  var now = DateTime(2060);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.restoreUserId('v38-user');
  });
  setUp(() {
    now = now.add(const Duration(minutes: 2));
    Clock.now = () => now;
  });
  tearDown(() {
    ErrorReporter.sendOverride = null;
    Clock.now = DateTime.now;
  });
  for (final (input, expected) in authorizationLineVectors) {
    test('V38 redacts the full Authorization line: ${jsonEncode(input)}', () {
      final sent = <Map<String, dynamic>>[];
      final reporter = ErrorReporter.instance;
      ErrorReporter.sendOverride = sent.add;
      reporter.report(
        message: input,
        level: 'warning',
        section: input,
        stacktrace: input,
        extra: {'diagnostic': input},
        tags: {'diagnostic': input},
      );
      final payload = sent.single;
      expect(payload['message'], expected);
      expect(payload['stacktrace'], expected);
      expect((payload['tags'] as Map)['section'], expected);
      expect((payload['extra'] as Map)['diagnostic'], expected);
      expect((payload['tags'] as Map)['diagnostic'], expected);
      expect(jsonEncode(payload), isNot(contains('SECRET')));
      expect(DiagnosticUrlSanitizer.sanitize(expected), expected);
    });
  }
}
