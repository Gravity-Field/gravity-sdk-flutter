import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sent = <Map<String, dynamic>>[];
  var now = DateTime(2030);
  setUpAll(
    () => SharedPreferences.setMockInitialValues({'gravity_device_id': ''}),
  );
  setUp(() async {
    SessionManager.instance.resetIdentityQueueForTests();
    await SessionManager.instance.resetSession();
    GravitySDK.instance.user = null;
    now = now.add(const Duration(minutes: 2));
    Clock.now = () => now;
    sent.clear();
    ErrorReporter.sendOverride = sent.add;
  });
  tearDown(() {
    ErrorReporter.sendOverride = null;
    Clock.now = DateTime.now;
    GravitySDK.instance.user = null;
  });

  Future<Map<String, dynamic>> report() async {
    ErrorReporter.instance.report(
      message: 'fallback',
      level: 'error',
      section: 'test',
    );
    await Future<void>.delayed(Duration.zero);
    return sent.single;
  }

  test('200 duplicate custom-user reports share at most two stored uid reads', () async {
    var reads = 0;
    ErrorReporter.readStoredUserIdForTests = () async {
      reads++;
      return null;
    };
    addTearDown(() => ErrorReporter.readStoredUserIdForTests = null);
    GravitySDK.instance.setUser('custom-burst', 'custom-session');
    for (var i = 0; i < 200; i++) {
      ErrorReporter.instance.report(message: 'duplicate-burst', level: 'error', section: 'burst');
    }
    await SessionManager.instance.getUserAfterIdentityUpdates(readStoredUserId: () async => null);
    await Future<void>.delayed(Duration.zero);
    expect(reads, lessThanOrEqualTo(2));
    expect(sent, hasLength(1));
  });

  test(
    'cold start generates the same device id requests use and a nonempty session',
    () async {
      final body = await report();
      expect(body['uid'], isNotEmpty);
      expect(body['uid'], await Prefs.instance.getDeviceId());
      expect(body['uid'], DeviceUtils.instance.deviceIdCache);
      expect(body['ses'], 'no-session');
    },
  );

  test('reads stored server uid with an empty session cache', () async {
    await Prefs.instance.setUserId('stored-server-uid');
    expect(SessionManager.instance.userId, isNull);
    expect((await report())['uid'], 'stored-server-uid');
  });

  test(
    'setUser before any anonymous response never supplies the report uid',
    () async {
      GravitySDK.instance.setUser('private-custom-id', 'custom-session');
      final body = await report();
      expect(body['uid'], DeviceUtils.instance.deviceIdCache);
      expect(body['uid'], isNotEmpty);
      expect(body['ses'], 'custom-session');
      expect(jsonEncode(body), isNot(contains('private-custom-id')));
    },
  );

  test('empty stored identities and custom session fall back', () async {
    await Prefs.instance.setUserId('');
    GravitySDK.instance.setUser('private-custom-id', '');
    final body = await report();
    expect(body['uid'], isNotEmpty);
    expect(body['ses'], 'no-session');
  });
  test('server session takes precedence over setUser session', () async {
    await SessionManager.instance.saveUser(
      null,
      const User(uid: 'server-id', ses: 'server-session'),
      SessionManager.instance.generation,
    );
    GravitySDK.instance.setUser('private-custom-id', 'custom-session');
    final body = await report();
    expect(body['uid'], 'server-id');
    expect(body['ses'], 'server-session');
    expect(jsonEncode(body), isNot(contains('private-custom-id')));
  });
  test('cold report waits for a pending identity replacement', () async {
    await Prefs.instance.setUserId('old-stored-user');
    final started = Completer<void>();
    final release = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) async {
      started.complete();
      await release.future;
    };
    final restoring = SessionManager.instance.restoreUserId('new-server-user');
    await started.future;
    ErrorReporter.instance.report(
      message: 'pending-restore',
      level: 'error',
      section: 'test',
    );
    await Future<void>.delayed(Duration.zero);
    final premature = List<Map<String, dynamic>>.from(sent);
    release.complete();
    await restoring;
    await Future<void>.delayed(Duration.zero);
    expect(premature, isEmpty);
    expect(sent.single['uid'], 'new-server-user');
    expect(sent.single['ses'], 'no-session');
  });

  test(
    'cold report does not wait for the network session it reports',
    () async {
      await Prefs.instance.setUserId('known-server-user');
      final gate = SessionManager.instance.beginSessionInitialization();
      try {
        final body = await report();
        expect(body['uid'], 'known-server-user');
      } finally {
        SessionManager.instance.completeSessionInitialization(gate);
      }
    },
  );
}
