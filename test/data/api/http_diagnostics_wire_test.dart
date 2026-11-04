import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late Api api;
  var status = 200;
  final requests = <Uri>[];
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Every destination below is this loopback fixture; the report guard stays on.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.text;
      request.response.write(status == 200 ? 'OK_BODY' : 'ERROR_BODY_SECRET');
      await request.response.close();
    });
    await GravitySDK.instance.initialize(
      apiKey: 'API_KEY_SECRET',
      section: 'logs',
      logLevel: LogLevel.debug,
    );
    Api.retryDelays = const [];
    api = Api();
  });
  tearDownAll(() async {
    LoggerManager.instance.configure(LogLevel.none);
    await server.close(force: true);
  });
  for (final code in [200, 401, 500]) {
    test(
      'HTTP diagnostics keep endpoint/status without secrets for $code',
      () async {
        status = code;
        requests.clear();
        talker.cleanHistory();
        final endpoint = 'http://127.0.0.1:${server.port}/log-$code';
        try {
          await api.triggerEventUrl(
            '$endpoint?token=QUERY_SECRET#FRAGMENT_SECRET',
            deferred: true,
          );
          expect(code, 200);
        } on DioException catch (error) {
          expect(error.response?.statusCode, code);
          expect(
            error.response?.data,
            'ERROR_BODY_SECRET',
            reason: 'logging must not modify the actual response',
          );
        }
        final logged = talker.history
            .map((data) => data.generateTextMessage())
            .join('\n');
        expect(
          requests.single.queryParameters['token'],
          'QUERY_SECRET',
          reason: 'logging must not modify the request',
        );
        expect(logged, contains(endpoint));
        expect(logged, matches(RegExp(r'(?:Status:|->)\s*' '$code' r'\b')));
        expect(
          logged,
          isNot(contains('ERROR_BODY_SECRET')),
          reason: 'HTTP error bodies never enter diagnostics',
        );
        for (final secret in [
          'QUERY_SECRET',
          'FRAGMENT_SECRET',
          'ERROR_BODY_SECRET',
          'API_KEY_SECRET',
        ]) {
          expect(logged, isNot(contains(secret)));
        }
      },
    );
  }
}
