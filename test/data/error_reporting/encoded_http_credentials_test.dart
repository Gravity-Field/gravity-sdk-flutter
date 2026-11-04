import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var now = DateTime(2060);
  final sent = <Map<String, dynamic>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.restoreUserId('encoded-fixture');
  });
  setUp(() {
    now = now.add(const Duration(minutes: 2));
    Clock.now = () => now;
    sent.clear();
    ErrorReporter.sendOverride = sent.add;
  });
  tearDown(() {
    Clock.now = DateTime.now;
    ErrorReporter.sendOverride = null;
  });
  for (final levels in [2, 3]) {
    for (final kind in ['dio', 'nested-dio', 'format']) {
      test(
        'xflu-2 $levels encoding levels remove credentials from $kind reports',
        () {
          var target =
              'https://user:SECRET@private.test/p?token=QUERY_SECRET#FRAGMENT_SECRET';
          for (var i = 0; i < levels; i++) {
            target = Uri.encodeComponent(target);
          }
          final input = kind == 'dio'
              ? target
              : 'https://host.test/redirect/$target';
          if (kind == 'format') {
            ErrorReporter.instance.report(
              message: FormatException('Invalid redirect', input).toString(),
              stacktrace: input,
              section: 'encoded',
              level: 'error',
              extra: {'url': input},
              tags: {'url': input},
            );
          } else {
            ErrorReporter.instance.reportDioError(
              error: DioException(
                requestOptions: RequestOptions(path: input),
                type: DioExceptionType.connectionError,
              ),
              section: 'encoded',
            );
          }
          final payload = jsonEncode(sent.single);
          expect(payload, isNot(contains('SECRET')));
          expect(
            payload,
            contains(
              kind == 'dio'
                  ? 'https://private.test/p'
                  : 'https://host.test/redirect/https://private.test/p',
            ),
          );
        },
      );
    }
  }
}
