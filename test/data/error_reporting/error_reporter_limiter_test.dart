import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var now = DateTime(2050);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SessionManager.instance.resetIdentityQueueForTests();
    await SessionManager.instance.restoreUserId('limiter-server');
    now = now.add(const Duration(minutes: 5));
    Clock.now = () => now;
  });
  tearDown(() {
    ErrorReporter.sendOverride = null;
    ErrorReporter.readStoredUserIdForTests = null;
    DeviceUtils.instance.deviceIdCache = null;
    Clock.now = DateTime.now;
  });
  void report(String message) => ErrorReporter.instance.report(
    message: message,
    level: 'error',
    section: 'limiter',
  );
  // Flush asynchronous completion handlers without sleeping or clock polling.
  Future<void> settled() => Future<void>(() {});

  test('an asynchronous delivery failure allows an identical retry', () async {
    final first = Completer<void>();
    final observed = first.future.catchError((Object _) {});
    var attempts = 0;
    Future<void> send(Map<String, dynamic> _) {
      attempts++;
      return attempts == 1 ? first.future : Future<void>.value();
    }

    ErrorReporter.sendOverride = send;
    report('async-failure');
    report('async-failure');
    expect(attempts, 1, reason: 'pending duplicate is reserved');
    first.completeError(StateError('async failure'));
    await observed;
    await settled();
    report('async-failure');
    await settled();
    expect(attempts, 2, reason: 'failed delivery cannot mark a hash delivered');
  });

  test(
    'successful dedup expires exactly 60 seconds after completion',
    () async {
      final delivery = Completer<void>();
      var attempts = 0;
      Future<void> send(Map<String, dynamic> _) {
        attempts++;
        return attempts == 1 ? delivery.future : Future<void>.value();
      }

      ErrorReporter.sendOverride = send;
      report('completion-window');
      now = now.add(const Duration(seconds: 30));
      delivery.complete();
      await delivery.future;
      await settled();
      now = now.add(const Duration(seconds: 59));
      report('completion-window');
      expect(
        attempts,
        1,
        reason: 'success is remembered at completion, not admission',
      );
      now = now.add(const Duration(seconds: 1));
      report('completion-window');
      await settled();
      expect(attempts, 2, reason: 'age >= 60 seconds expires');
    },
  );

  test('failed attempts spend budget and expire at exactly 60 seconds', () {
    var attempts = 0;
    ErrorReporter.sendOverride = (_) {
      attempts++;
      throw StateError('send failure');
    };
    for (var i = 0; i < 11; i++) {
      report('failed-budget');
    }
    expect(attempts, 10);
    now = now.add(const Duration(seconds: 59));
    report('failed-budget');
    expect(attempts, 10);
    now = now.add(const Duration(seconds: 1));
    report('failed-budget');
    expect(attempts, 11);
  });

  test('attempt budget is timestamped before identity resolution', () async {
    await SessionManager.instance.resetSession();
    final read = Completer<String?>();
    final reading = Completer<void>();
    ErrorReporter.readStoredUserIdForTests = () {
      if (!reading.isCompleted) reading.complete();
      return read.future;
    };
    DeviceUtils.instance.deviceIdCache = 'limiter-device';
    final sent = <Map<String, dynamic>>[];
    ErrorReporter.sendOverride = sent.add;
    report('waiting-for-identity');
    await reading.future;
    now = now.add(const Duration(seconds: 60));
    read.complete(null);
    await settled();
    expect(sent, hasLength(1));
    for (var i = 0; i < 10; i++) {
      report('after-identity-$i');
    }
    await settled();
    expect(
      sent,
      hasLength(11),
      reason: 'the held attempt aged out at admission + 60s',
    );
  });

  test(
    'pending deliveries stay bounded after attempt timestamps expire',
    () async {
      final delivery = Completer<void>();
      var attempts = 0;
      Future<void> send(Map<String, dynamic> _) {
        attempts++;
        return delivery.future;
      }

      ErrorReporter.sendOverride = send;
      for (var i = 0; i < 10; i++) {
        report('pending-$i');
      }
      now = now.add(const Duration(seconds: 61));
      report('eleventh-pending');
      final beforeCompletion = attempts;
      delivery.complete();
      await delivery.future;
      await settled();
      expect(
        beforeCompletion,
        10,
        reason: 'ten hung deliveries remain reserved across expiry',
      );
      report('eleventh-pending');
      await settled();
      expect(attempts, 11);
    },
  );
}
