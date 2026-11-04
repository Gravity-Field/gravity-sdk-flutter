import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sanitizerVectors = <(String, String, String)>[
  (
    'V1',
    'https://public.test/,https://user:SECRET@private.test/path?token=x',
    'https://public.test/,https://private.test/path',
  ),
  ('V2', 'https://user:SE/CRET@host/p', 'https://[redacted]'),
  ('V3', 'https://user:SE?CRET@host/p', 'https://[redacted]'),
  ('V4', 'https://user:SE#CRET@host/p', 'https://[redacted]'),
  ('V5', 'wss://user:SECRET@socket.test/x', 'wss://socket.test/x'),
  (
    'V6',
    'https://proxy.test/redirect/ftp://user:SECRET@private.test/x',
    'https://proxy.test/redirect/ftp://private.test/x',
  ),
  ('V7', '//user:SECRET@host/p', '//host/p'),
  (
    'V8',
    'POST https://api.test/v1/choose?email=a@b.com failed for user@example.com',
    'POST https://api.test/v1/choose failed for user@example.com',
  ),
  (
    'V9',
    'https://host.test/users/@alice/profile',
    'https://host.test/users/@alice/profile',
  ),
  (
    'V10',
    '#0 main (file:///Users/me/app/lib/main.dart:10:5)',
    '#0 main (file:///Users/me/app/lib/main.dart:10:5)',
  ),
  (
    'V11',
    'Illegal character in authority at index 8: https://user:SE CRET@host/p',
    'Illegal character in authority at index 8: https://[redacted]host/p',
  ),
  ('V12', 'https://u:pa ss@h', 'https://[redacted]h'),
  ('V13', r'https:\/\/user:SECRET@host\/p', 'https://host/p'),
  ('V14', 'https%3A%2F%2Fuser%3ASECRET%40host', 'https://host'),
  ('V15', 'HTTPS://User:SECRET@Host.test/P?q=1#f', 'HTTPS://Host.test/P'),
  ('V16', 'https://host:8443/users/@alice/profile', 'https://[redacted]'),
  ('V17', 'https://public.test:443/p?email=user@X', 'https://[redacted]'),
  ('V18', 'https://user:123/456@host/p', 'https://[redacted]'),
  (
    'V19',
    'https://[::1]:8443/users/@alice/profile?x=1',
    'https://[::1]:8443/users/@alice/profile',
  ),
  (
    'V20',
    'https://host:8443/plain/path?token=x',
    'https://host:8443/plain/path',
  ),
  ('V21', 'content:https://user:SECRET@host/p', 'content:https://host/p'),
  ('V22', 'redis://user:SECRET@host:6379/0', 'redis://host:6379/0'),
  (
    'V23',
    'POST https://api.test:8443 failed for user@example.com',
    'POST https://api.test:8443 failed for user@example.com',
  ),
  (
    'V24',
    'connect https://api.test:8443: timeout; admin@corp.test notified',
    'connect https://api.test:8443: timeout; admin@corp.test notified',
  ),
  (
    'V25',
    'url:https://user:SECRET@host.test/p?token=x',
    'url:https://host.test/p',
  ),
  (
    'V26',
    'REQUEST:https://user:SECRET@host.test/p',
    'REQUEST:https://host.test/p',
  ),
  (
    'V27',
    'failed:reason:https://user:SECRET@host.test/p tail',
    'failed:reason:https://host.test/p tail',
  ),
  (
    'V28',
    'jdbc:postgresql://user:SECRET@host.test/db',
    'jdbc:postgresql://host.test/db',
  ),
  ('V29', 'blob:https://user:SECRET@host.test/x', 'blob:https://host.test/x'),
  ('V30', 'https://user:SECRET@host.test/p', 'https://host.test/p'),
  ('V31', r'https:\\/\\/user:SECRET@host\\/p', 'https://host/p'),
  ('V32', 'https:%2F%2Fuser:SECRET@host.test/p', 'https://host.test/p'),
  ('V33', 'https://user:SECRET/path', 'https://[redacted]'),
  ('V34', 'https://api.test:', 'https://api.test:'),
  ('V35', 'https://[user:123]/SECRET@host/p', 'https://[redacted]'),

  ('V36', 'retry-2.https://user:SECRET@host/p', 'retry-2.https://host/p'),
  ('V37', 'Authorization: Bearer ABC123', 'Authorization: [redacted]'),
  ('V38', 'authorization: [Bearer SECRET]', 'authorization: [redacted]'),
];

void main() {
  final sent = <Map<String, dynamic>>[];
  var now = DateTime(2035);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.restoreUserId('contract-user');
  });
  setUp(() {
    now = now.add(const Duration(minutes: 2));
    Clock.now = () => now;
    sent.clear();
    ErrorReporter.sendOverride = sent.add;
  });
  tearDown(() {
    ErrorReporter.sendOverride = null;
    Clock.now = DateTime.now;
  });

  void report(String input) => ErrorReporter.instance.report(
    message: input,
    stacktrace: input,
    level: 'warning',
    section: input,
    tags: {'url': input},
    extra: {'url': input},
  );

  for (final (id, input, expected) in sanitizerVectors) {
    test('$id sanitizer contract preserves endpoints and removes secrets', () {
      report(input);
      final payload = sent.single;
      expect(payload['message'], expected);
      expect(payload['stacktrace'], expected);
      expect(payload['extra'], {'url': expected});
      expect(payload['tags'], {'url': expected, 'section': expected});
      expect(jsonEncode(payload), isNot(contains('SECRET')));
      if (id == 'V2' || id == 'V3' || id == 'V4' || id == 'V11') {
        expect(
          (payload['message'] as String).split('//').last,
          isNot(contains('SE')),
        );
        expect(jsonEncode(payload), isNot(contains('CRET')));
      }
      if (id == 'V37') expect(jsonEncode(payload), isNot(contains('ABC123')));
      if (id == 'V18') {
        expect(jsonEncode(payload), isNot(contains('123')));
        expect(jsonEncode(payload), isNot(contains('456')));
      }
      if (id == 'V12') {
        expect(jsonEncode(payload), isNot(contains('pa')));
        expect(jsonEncode(payload), isNot(contains('ss@')));
      }
    });
  }

  for (final input in [
    'content:text/plain?QUERY_SECRET=https://user:SECRET@host/p',
    'data:application/test#FRAGMENT_SECRET=redis://user:SECRET@host/p',
  ]) {
    test(
      'R1a/R6 nested schemes remain removed inside non-network query data: $input',
      () {
        report(input);
        expect(sent.single['message'], input.split(RegExp('[?#]')).first);
        expect(jsonEncode(sent.single), isNot(contains('SECRET')));
      },
    );
  }

  for (final (input, expected) in [
    ('mongodb://user:SECRET@host:27017/db?x=secret', 'mongodb://host:27017/db'),
    ('amqp://user:SECRET@host/vhost#fragment', 'amqp://host/vhost'),
    ('custom+v1.2-3://user:SECRET@host/p', 'custom+v1.2-3://host/p'),
    (r'redis:\/\/user:SECRET@host\/p', 'redis://host/p'),
    ('redis%3A%2F%2Fuser%3ASECRET%40host%2Fp', 'redis://host/p'),
    ('jar:file:///a/b.dart:1:2?secret=value', 'jar:file:///a/b.dart:1:2'),
    (
      'content:content:https://user:SECRET@host/p',
      'content:content:https://host/p',
    ),
    ('file://user:SECRET@host/p', 'file://host/p'),
  ]) {
    test('R1a generic scheme and nested prefix: $input', () {
      report(input);
      expect(sent.single['message'], expected);
      expect(jsonEncode(sent.single), isNot(contains('SECRET')));
    });
  }

  for (final (input, expected) in [
    (r'\/\/user:SECRET@host\/p', '//host/p'),
    ('%2F%2Fuser%3ASECRET%40host%2Fp', '//host/p'),
    (
      'https://proxy.test/p/%2F%2Fuser%3ASECRET%40host%2Fp',
      'https://proxy.test/p///host/p',
    ),
    ('https://host.test/p///x', 'https://host.test/p///x'),
    ('https://u:pa"ss@h', 'https://[redacted]h'),
    ("https://u:pa'ss@h", 'https://[redacted]h'),
  ]) {
    test('R1/R5/R7 retain endpoints across slash and quote forms: $input', () {
      report(input);
      expect(sent.single['message'], expected);
      expect(jsonEncode(sent.single), isNot(contains('SECRET')));
    });
  }

  for (final input in [
    r'https://proxy.test/p/https:\/\/user:SECRET@host\/p',
    'https://proxy.test/p/https%3A%2F%2Fuser%3ASECRET%40host%2Fp',
  ]) {
    test('R1/R7 sanitize escaped URL nested in a path: $input', () {
      report(input);
      expect(sent.single['message'], 'https://proxy.test/p/https://host/p');
      expect(jsonEncode(sent.single), isNot(contains('SECRET')));
    });
  }

  for (final input in [
    'POST https://api.test/v1 failed for user@example.com',
    'see //comment then mail me@x',
  ]) {
    test('flu-10 keeps later non-URL at-sign text: $input', () {
      report(input);
      expect(sent.single['message'], input);
    });
  }

  test(
    'flu-12 drops only a URL crossing the input bound and keeps following text',
    () {
      report('before https://user:${'p' * 55000}@host/p after');
      expect(sent.single['message'], 'before  after');
      expect(sent.single['stacktrace'], 'before  after');
    },
  );

  for (final scheme in ['file', 'package', 'dart', 'content', 'data']) {
    test('R6 keeps $scheme locations while removing query and fragment', () {
      report('$scheme:///a/b.dart:1:2?secret=value#fragment following');
      expect(sent.single['message'], '$scheme:///a/b.dart:1:2 following');
    });
  }
}
