import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an error report carries: nothing that identifies the user or leaks
/// what the server answered, and a budget of ten reports a minute that only
/// distinct reports spend.
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
    test('carries no uid', () {
      expect(SessionManager.instance.userId, 'device-uid-1234', reason: 'the uid is known to the SDK');

      report('no-uid-probe');

      expect(sent.single.containsKey('uid'), isFalse);
      expect(jsonEncode(sent.single), isNot(contains('device-uid-1234')));
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
