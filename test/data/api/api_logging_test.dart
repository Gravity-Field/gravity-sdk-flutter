import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:talker/talker.dart' show Talker, TalkerData, TalkerKey;

/// The HTTP logger of [Api] is attached once, when the repository is built,
/// yet the log level can be changed by any later initialize(): the level set
/// last must govern it. The API key in the Authorization header never reaches
/// the log, at any level.
void main() {
  late HttpServer server;
  late String url;

  setUpAll(() async {
    ErrorReporter.disableNetworkForTests = true;
    GravitySDK.instance.apiKey = 'secret-api-key';
    GravitySDK.instance.section = 'logging-section';
    Api.retryDelays = const [];

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      await request.response.close();
    });
    url = 'http://127.0.0.1:${server.port}/pixel';
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  /// HTTP request lines [talker] emits while [send] runs.
  Future<List<TalkerData>> requestLogsOf(Talker talker, Future<void> Function() send) async {
    final logs = <TalkerData>[];
    final subscription = talker.stream.listen((data) {
      if (data.key == TalkerKey.httpRequest) logs.add(data);
    });
    await send();
    await subscription.cancel();
    return logs;
  }

  test('LogLevel.none set after the Api was built silences its HTTP log', () async {
    LoggerManager.instance.configure(LogLevel.debug);
    final loggerSeenByApi = LoggerManager.instance.talker;
    final api = Api();

    LoggerManager.instance.configure(LogLevel.none);

    final logs = await requestLogsOf(loggerSeenByApi, () => api.triggerEventUrl(url));
    expect(logs, isEmpty);
  });

  test('a level raised after the Api was built turns its HTTP log back on', () async {
    LoggerManager.instance.configure(LogLevel.none);
    final api = Api();

    LoggerManager.instance.configure(LogLevel.debug);

    final logs = await requestLogsOf(LoggerManager.instance.talker, () => api.triggerEventUrl(url));
    expect(logs, hasLength(1));
  });

  test('the Authorization header is masked in the request log', () async {
    LoggerManager.instance.configure(LogLevel.debug);
    final api = Api();

    final logs = await requestLogsOf(LoggerManager.instance.talker, () => api.triggerEventUrl(url));

    final text = logs.single.generateTextMessage();
    expect(text, contains('Authorization'));
    expect(text, contains('*****'));
    expect(text, isNot(contains('secret-api-key')));
  });
}
