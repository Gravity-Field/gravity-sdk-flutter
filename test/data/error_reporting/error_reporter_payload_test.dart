import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an error report carries: the device uid the endpoint requires but no
/// id the app chose, nothing that leaks what the server answered, and a budget
/// of ten reports a minute that only distinct reports spend.
void main() {
  final sent = <Map<String, dynamic>>[];
  var now = DateTime(2026, 1, 1);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    Clock.now = () => now;
    // Puts the uid into the session cache, where the reporter used to take it
    // from.
    await SessionManager.instance.restoreUserId('device-uid-1234');
  });

  tearDownAll(() {
    Clock.now = DateTime.now;
  });

  setUp(() {
    SessionManager.instance.resetIdentityQueueForTests();
    // Every test starts past the one-minute windows of the previous one.
    now = now.add(const Duration(minutes: 5));
    sent.clear();
    ErrorReporter.sendOverride = sent.add;
  });

  tearDown(() {
    ErrorReporter.sendOverride = null;
  });

  void report(String message, {String? stacktrace, Map<String, dynamic>? extra, Map<String, String>? tags}) {
    ErrorReporter.instance.report(
      message: message,
      level: 'warning',
      section: 'PayloadTest',
      stacktrace: stacktrace,
      extra: extra,
      tags: tags,
    );
  }

  group('payload', () {
    test('carries the device uid, not the id passed to setUser', () {
      expect(SessionManager.instance.userId, 'device-uid-1234', reason: 'the uid is known to the SDK');
      GravitySDK.instance.setUser('private-customer-id', 'customer-session');
      addTearDown(() => GravitySDK.instance.user = null);

      report('uid-probe');

      expect(sent.single['uid'], 'device-uid-1234');
      expect(jsonEncode(sent.single), isNot(contains('private-customer-id')));
    });

    test('puts the section into tags without touching the caller tags', () {
      final tags = {'category': 'ui'};
      report('section-probe', tags: tags);

      expect(sent.single['tags'], {'category': 'ui', 'section': 'PayloadTest'});
      expect(tags, {'category': 'ui'});
    });

    test('strips query, fragment and credentials from URLs in every string', () {
      report(
        'GET https://user:pass@ev.example.com:8443/v2/engagement?uid=abc&token=t#frag failed',
        stacktrace: '#0 fetch (see http://ev.example.com/pixel?cuid=secret)',
        extra: {
          'url': 'https://ev.example.com/v2/engagement?type=WCLICK&uid=abc',
          'nested': {
            'urls': ['http://a.example.com/p?q=1', 'plain text'],
          },
          'count': 3,
        },
        tags: {'endpoint': 'https://ev.example.com/x?y=1'},
      );

      final payload = sent.single;
      expect(payload['message'], 'GET https://ev.example.com:8443/v2/engagement failed');
      // The closing bracket goes with the query: a query may hold brackets
      // of its own, so nothing after `?` is trusted to end it.
      expect(payload['stacktrace'], '#0 fetch (see http://ev.example.com/pixel');
      expect(payload['extra'], {
        'url': 'https://ev.example.com/v2/engagement',
        'nested': {
          'urls': ['http://a.example.com/p', 'plain text'],
        },
        'count': 3,
      });
      expect((payload['tags'] as Map)['endpoint'], 'https://ev.example.com/x');
    });
  });

  group('reportDioError', () {
    DioException badResponse() {
      final options = RequestOptions(
        method: 'POST',
        path: 'https://evs.example.com/v2/choose?apiKey=k&uid=abc',
      );
      return DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        message: 'server said {"uid":"body-uid-777"}',
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: '{"uid":"body-uid-777","error":"boom"}',
        ),
      );
    }

    test('sends neither the response body nor the query of the URL', () {
      ErrorReporter.instance.reportDioError(error: badResponse(), section: 'Api./choose');

      final payload = sent.single;
      expect(jsonEncode(payload), isNot(contains('body-uid-777')));
      expect(jsonEncode(payload), isNot(contains('apiKey')));
      expect((payload['extra'] as Map).containsKey('responseBody'), isFalse);
      expect(payload['extra'], {
        'url': 'https://evs.example.com/v2/choose',
        'httpMethod': 'POST',
        'httpStatus': 500,
        'dioType': 'badResponse',
      });
    });

    test('builds the message from the request, not from the error text', () {
      ErrorReporter.instance.reportDioError(error: badResponse(), section: 'Api./choose');

      expect(sent.single['message'], 'DioException [badResponse] POST https://evs.example.com/v2/choose -> 500');
    });

    test('says so when there was no response', () {
      ErrorReporter.instance.reportDioError(
        error: DioException(
          requestOptions: RequestOptions(method: 'GET', path: 'http://127.0.0.1:1/pixel?x=1'),
          type: DioExceptionType.connectionError,
        ),
        section: 'Api.http://127.0.0.1:1/pixel?x=1',
      );

      expect(sent.single['message'], 'DioException [connectionError] GET http://127.0.0.1:1/pixel -> no response');
      expect((sent.single['tags'] as Map)['section'], 'Api.http://127.0.0.1:1/pixel');
    });
  });

  test('strips the query of a URL with a bracketed IPv6 host', () {
    const url = 'http://[::1]:8080/pixel?uid=ipv6-query-uid';
    ErrorReporter.instance.reportDioError(
      error: DioException(
        requestOptions: RequestOptions(method: 'GET', path: url),
        type: DioExceptionType.connectionError,
      ),
      section: 'Api.$url',
    );

    final payload = sent.single;
    expect(jsonEncode(payload), isNot(contains('ipv6-query-uid')));
    expect(payload['message'], 'DioException [connectionError] GET http://[::1]:8080/pixel -> no response');
    expect((payload['extra'] as Map)['url'], 'http://[::1]:8080/pixel');
    expect((payload['tags'] as Map)['section'], 'Api.http://[::1]:8080/pixel');
  });

  test('drops the whole query even where it holds commas or brackets', () {
    report(
      'GET http://[::1]:8080/pixel?uid=,comma-secret failed; '
      'see https://ev.example.com/p?a=(x),y&uid=bracket-secret#f,frag-secret.',
    );

    final message = sent.single['message'] as String;
    expect(message, 'GET http://[::1]:8080/pixel failed; see https://ev.example.com/p');
  });

  for (final url in [
    'https://host/p(1)?uid=SECRET',
    'https://host/a,b?uid=SECRET',
    'https://host/{id}?token=SECRET',
    'https://host/a[b?uid=SECRET',
    'https://u:p@[::1/p?uid=1',
    'https://user:p@ss@host.com/p?uid=SECRET',
  ]) {
    test('sanitizes every report text field: $url', () {
      ErrorReporter.instance.report(
        message: url,
        stacktrace: url,
        level: 'error',
        section: url,
        tags: {'url': url},
        extra: {
          'nested': [url],
        },
      );
      final body = jsonEncode(sent.single);
      for (final secret in [
        'SECRET',
        '?uid',
        '?token',
        'u:p',
        'user:p',
        r'$1',
      ]) {
        expect(body, isNot(contains(secret)));
      }
      expect(sent.single['message'], startsWith('https://'));
    });
  }

  for (final (input, expected) in [
    ('https://public.test/,https://user:SECRET@private.test/path?token=x',
     'https://public.test/,https://private.test/path'),
    ('https://public.test,https://user:SECRET@private.test/path',
     'https://public.test,https://private.test/path'),
    ('https://public.test/redirect/HTTPS://user:SECRET@private.test/path#fragment',
     'https://public.test/redirect/HTTPS://private.test/path'),
    ('https://public.test/?token=SECRET,https://user:OTHER@private.test/path',
     'https://public.test/'),
    ('https://public.test/#fragment=SECRET,https://user:OTHER@private.test/path',
     'https://public.test/'),
  ]) {
    test('sanitizes every embedded authority without retaining query tails: $input', () {
      ErrorReporter.instance.report(
        message: input,
        stacktrace: input,
        level: 'error',
        section: input,
        tags: {'url': input},
        extra: {'nested': [input]},
      );
      final body = sent.single;
      expect(body['message'], expected);
      expect(body['stacktrace'], expected);
      expect(body['tags'], {'url': expected, 'section': expected});
      expect(body['extra'], {'nested': [expected]});
      expect(jsonEncode(body), isNot(contains('SECRET')));
      expect(jsonEncode(body), isNot(contains('OTHER')));
    });
  }

  for (final (url, clean) in [
    ('https://user:SE/CRET@host/p', 'https://[redacted]'),
    ('https://user:SE?CRET@host/p', 'https://[redacted]'),
    ('https://user:SE#CRET@host/p', 'https://[redacted]'),
    ('wss://user:SECRET@host/p?token=PRIVATE', 'wss://host/p'),
    ('ftp://user:SECRET@host/p?token=PRIVATE', 'ftp://host/p'),
    ('//user:SECRET@host/p?token=PRIVATE', '//host/p'),
    ('https://u:pa ss@h', 'https://[redacted]h'),
  ]) {
    test('removes malformed and non-http userinfo: $url', () {
      report(url, stacktrace: url, extra: {'url': url}, tags: {'url': url});
      expect(sent.single['message'], clean);
      expect(sent.single['stacktrace'], clean);
      expect(sent.single['extra'], {'url': clean});
      expect((sent.single['tags'] as Map)['url'], clean);
    });
  }

  for (final (url, endpoint) in [
    ('https://api.example.test/choose?email=person@example.test', 'https://api.example.test/choose'),
    ('https://api.example.test:443/choose?email=person@example.test', 'https://[redacted]'),
    ('https://api.example.test/choose#person@example.test', 'https://api.example.test/choose'),
  ]) {
    test('sanitizes at-sign query data under the authority ambiguity rule: $url', () {
      report(url, stacktrace: url, extra: {'url': url}, tags: {'url': url});
      expect(sent.single['message'], endpoint);
      expect(sent.single['stacktrace'], endpoint);
      expect(sent.single['extra'], {'url': endpoint});
      expect((sent.single['tags'] as Map)['url'], endpoint);
      expect(jsonEncode(sent.single), isNot(contains('person@')));
    });
  }

  test('bounded long diagnostics preserve a complete legitimate endpoint', () {
    report('GET https://api.example.test/choose finished ${'x' * 20000}');
    expect(sent.single['message'], startsWith('GET https://api.example.test/choose finished '));
    expect((sent.single['message'] as String).length, 1000);
  });

  test('query text containing at-sign cannot become a reported host', () {
    report('https://public.test:443/p?email=user@QUERY_SECRET');
    expect(jsonEncode(sent.single), isNot(contains('QUERY_SECRET')));
  });

  test('bounded input never retains a raw-space credential prefix', () {
    const paddingUrl = 'https://padding.test/?';
    const credential = 'https://u:pa ssSECRET';
    final prefix = '$paddingUrl${'x' * (10000 - paddingUrl.length - credential.length - 1)} ';
    report('$prefix$credential${'x' * 100}@host/path');
    expect(sent.single['message'], 'https://padding.test/ ');
  });

  test(
    'bounds million-character URL processing without dropping the report',
    () {
      final url = 'https://host/${'a(' * 500000}?uid=SECRET';
      report(url, stacktrace: url, extra: {'url': url}, tags: {'url': url});
      expect(sent, hasLength(1));
      expect(jsonEncode(sent.single), isNot(contains('SECRET')));
      expect(sent.single['message'], isEmpty);
      expect(sent.single['stacktrace'], isEmpty);
    },
  );

  test('long plain text still uses the final message and stacktrace limits', () {
    report('x' * 100000, stacktrace: 'y' * 100000);
    expect((sent.single['message'] as String).length, 1000);
    expect((sent.single['stacktrace'] as String).length, 5000);
    expect(sent.single['message'], endsWith('...'));
    expect(sent.single['stacktrace'], endsWith('...'));
  });

  for (final field in ['message', 'stacktrace']) {
    for (final part in ['SECRETPASS', 'uid=SECRET']) {
      test('drops a $field URL cut inside $part by the input bound', () {
        const url = 'https://user:SECRETPASS@host/p?uid=SECRET';
        final bound = field == 'message' ? 10000 : 50000;
        final cut = url.indexOf(part) + (part == 'SECRETPASS' ? 6 : 7);
        // Sanitizing the first URL removes this padding, exposing the partial
        // credentials at the end of the bounded input in the final payload.
        const paddingUrl = 'https://padding.test/?';
        final prefix = '$paddingUrl${'x' * (bound - cut - paddingUrl.length - 1)} ';
        final text = '$prefix$url';
        report(field == 'message' ? text : 'stack-bound', stacktrace: field == 'stacktrace' ? text : null);
        expect(sent.single[field], 'https://padding.test/ ');
        expect(sent.single[field], isNot(contains('SEC')));
        expect(sent.single[field], isNot(contains('user:')));
      });
    }
  }

  test('a synchronous send failure does not suppress a retry as a duplicate', () {
    ErrorReporter.sendOverride = (_) => throw StateError('transport unavailable');
    report('retry-after-send-failure');
    ErrorReporter.sendOverride = sent.add;
    report('retry-after-send-failure');
    expect(sent, hasLength(1));
  });

  group('limits', () {
    test('duplicates do not spend the rate limit', () {
      for (var i = 0; i < 10; i++) {
        report('the-same-failure');
      }
      report('a-different-failure');

      expect(sent.map((p) => p['message']), ['the-same-failure', 'a-different-failure']);
    });

    test('a duplicate is held back for a minute, then reported again', () {
      report('recurring-failure');
      now = now.add(const Duration(seconds: 30));
      report('recurring-failure');
      now = now.add(const Duration(seconds: 31));
      report('recurring-failure');

      expect(sent.map((p) => p['message']), ['recurring-failure', 'recurring-failure']);
    });

    test('a report the rate limit turned away is not remembered as sent', () {
      for (var i = 0; i < 10; i++) {
        report('filler-$i');
      }
      now = now.add(const Duration(seconds: 30));
      report('turned-away');
      expect(sent, hasLength(10));

      // The fillers have left the window, the turned-away report has not
      // been in it at all.
      now = now.add(const Duration(seconds: 31));
      report('turned-away');

      expect(sent.last['message'], 'turned-away');
    });
  });
}
