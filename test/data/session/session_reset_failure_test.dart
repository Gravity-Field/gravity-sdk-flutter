import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Refuses a configured number of writes or removals of the uid key, the way
/// Android does when `commit()` returns false. Everything else is a normal
/// in-memory store, so the outbox and the device id are untouched.
class _PlatformDisk extends InMemorySharedPreferencesStore {
  _PlatformDisk() : super.empty();

  int rejectUserIdWrites = 0;
  int rejectUserIdRemovals = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_user_id') && rejectUserIdWrites > 0) {
      rejectUserIdWrites--;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key.endsWith('gravity_user_id') && rejectUserIdRemovals > 0) {
      rejectUserIdRemovals--;
      return false;
    }
    return super.remove(key);
  }

  Future<String?> storedUserId() async => (await getAll())['flutter.gravity_user_id'] as String?;
}

class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

/// Storage that refuses to write is the one failure the identity API cannot
/// hide: resetUser() and restoreUserId() promise the device state changed,
/// while a uid learned from a delivered response must never turn that
/// response into a failed request.
void main() {
  late HttpServer server;
  late _PlatformDisk disk;
  final notified = <String?>[];
  final reports = <({String section, Map<String, dynamic> payload})>[];
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;
  var uidForVisit = 'server-uid';

  PageContext ctx() => const PageContext(type: ContextType.homepage, data: [], location: '/home');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    disk = _PlatformDisk();
    SharedPreferencesStorePlatform.instance = disk;
    PackageInfo.setMockInitialValues(
      appName: 'reset-failure-test',
      packageName: 'ai.gravityfield.resetfailuretest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'reset-ua', id: 'reset-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': uidForVisit, 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'reset-key', section: 'reset-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    ErrorReporter.observer = null;
    OutboxDispatcher.lifecycleObserverEnabled = true;
    Api.retryDelays = originalRetryDelays;
    OutboxDispatcher.timerFactory = originalTimerFactory;
  });

  setUp(() async {
    SessionManager.instance.onUserIdChanged = null;
    disk.rejectUserIdWrites = 0;
    disk.rejectUserIdRemovals = 0;
    uidForVisit = 'server-uid';
    await SessionManager.instance.resetSession();
    SessionManager.instance.onUserIdChanged = notified.add;
    notified.clear();
    reports.clear();
    ErrorReporter.observer = (section, payload) => reports.add((section: section, payload: payload));
  });

  tearDown(() {
    ErrorReporter.observer = null;
    SessionManager.instance.onUserIdChanged = null;
    disk.rejectUserIdWrites = 0;
    disk.rejectUserIdRemovals = 0;
  });

  test('resetUser whose removal the platform refuses reports the failure to the caller', () async {
    await Prefs.instance.setUserId('uid-from-a-previous-launch');
    disk.rejectUserIdRemovals = 2;

    await expectLater(GravitySDK.instance.resetUser(), throwsA(isA<StateError>()));

    expect(await disk.storedUserId(), 'uid-from-a-previous-launch', reason: 'the disk really kept it');
    expect(SessionManager.instance.userId, isNull);
    expect(SessionManager.instance.sessionId, isNull);
    expect(SessionManager.instance.isInitializing, isFalse, reason: 'the reset gate must not stay open');
    await Future<void>.delayed(Duration.zero);
    expect(notified, <String?>[null], reason: 'the session is gone from memory whatever the disk did');
  });

  test('restoreUserId whose write the platform refuses throws and frees the gate', () async {
    disk.rejectUserIdWrites = 2;

    await expectLater(GravitySDK.instance.restoreUserId('wanted-uid'), throwsA(isA<StateError>()));

    expect(SessionManager.instance.isInitializing, isFalse, reason: 'the restore gate must not stay open');
    expect(SessionManager.instance.userId, isNull, reason: 'nothing was stored, so nothing is cached');
    expect(await disk.storedUserId(), isNull);

    // The serialized write queue survived the failure.
    await GravitySDK.instance.restoreUserId('second-uid');
    expect(SessionManager.instance.userId, 'second-uid');
    expect(await disk.storedUserId(), 'second-uid');
  });

  test('a uid the disk refused does not fail the delivered request and is written again', () async {
    disk.rejectUserIdWrites = 2;

    final response = await GravityRepo.instance.visit(pageContext: ctx(), options: Options());

    expect(response.user.uid, 'server-uid', reason: 'the response was delivered; storage is not its problem');
    expect(await disk.storedUserId(), isNull);
    expect(
      reports.where((r) => r.section == 'SessionManager.saveUser'),
      isNotEmpty,
      reason: 'a swallowed storage failure must still be reported',
    );
    expect(SessionManager.instance.userId, 'server-uid', reason: 'waiters must not fall back to a cold start');
    await Future<void>.delayed(Duration.zero);
    expect(notified, ['server-uid'], reason: 'the listener speaks for the same uid getUserId() answers');

    // The same uid comes back from the next response: the unconfirmed write is
    // repeated instead of being skipped as "already cached".
    await GravityRepo.instance.visit(pageContext: ctx(), options: Options());
    expect(await disk.storedUserId(), 'server-uid');
    await Future<void>.delayed(Duration.zero);
    expect(notified, ['server-uid'], reason: 'the write landing later is not a second change');
  });

  test('a uid known only in memory is still reported by getUserId and the listener', () async {
    disk.rejectUserIdWrites = 2;

    await SessionManager.instance.saveUser(
      null,
      const User(uid: 'server-uid', ses: 'server-ses'),
      SessionManager.instance.generation,
    );
    await Future<void>.delayed(Duration.zero);

    expect(await disk.storedUserId(), isNull, reason: 'the device kept nothing');
    expect(await GravitySDK.instance.getUserId(), 'server-uid');
    expect(notified, ['server-uid'], reason: 'the two ways of learning the uid must not disagree');
  });
}
