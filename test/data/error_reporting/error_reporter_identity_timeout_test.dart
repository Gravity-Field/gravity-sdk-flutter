import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final lateError in [false, true]) {
    testWidgets(
      'flu-13 hung identity reads fall back and clear hashes (lateError=$lateError)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.runAsync(SessionManager.instance.resetSession);
        var now = DateTime(2040, lateError ? 2 : 1);
        Clock.now = () => now;
        DeviceUtils.instance.deviceIdCache = 'timeout-device';
        final blocked = Completer<String?>();
        var reads = 0;
        ErrorReporter.readStoredUserIdForTests = () {
          reads++;
          return blocked.future;
        };
        final sent = <Map<String, dynamic>>[];
        ErrorReporter.sendOverride = sent.add;
        addTearDown(() {
          ErrorReporter.sendOverride = null;
          ErrorReporter.readStoredUserIdForTests = null;
          DeviceUtils.instance.deviceIdCache = null;
          Clock.now = DateTime.now;
          SessionManager.instance.resetIdentityQueueForTests();
        });
        void report(String message) => ErrorReporter.instance.report(
          message: message,
          level: 'error',
          section: 'timeout',
        );
        for (var i = 0; i < 10; i++) {
          report('hung-identity-$i');
        }
        while (reads == 0) {
          await tester.pump();
          await tester.runAsync(() => Future<void>(() {}));
        }
        await tester.pump(const Duration(seconds: 10));
        expect(sent, hasLength(10));
        expect(
          sent.every((payload) => payload['uid'] == 'timeout-device'),
          isTrue,
        );
        now = now.add(const Duration(minutes: 2));
        report('hung-identity-0');
        await tester.pump(const Duration(seconds: 10));
        expect(
          sent,
          hasLength(11),
          reason: 'expired dedup must not leave an async hash pinned',
        );
        expect(
          reads,
          1,
          reason:
              'a stuck read must not enqueue another FIFO operation per timeout',
        );
        if (lateError) {
          blocked.completeError(StateError('late read failure'));
          ErrorReporter.readStoredUserIdForTests = () async {
            reads++;
            return 'late-stored-server';
          };
        } else {
          blocked.complete('late-stored-server');
        }
        await tester.pump();
        expect(
          sent,
          hasLength(11),
          reason: 'late completion must not send a timed-out report again',
        );
        now = now.add(const Duration(minutes: 2));
        report('hung-identity-0');
        await tester.pump();
        expect(sent.last['uid'], 'late-stored-server');
        expect(sent, hasLength(12));
        expect(reads, lateError ? 2 : 1);
      },
    );
  }
  testWidgets('disabled unobserved reports do not start identity work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(SessionManager.instance.resetSession);
    var reads = 0;
    ErrorReporter.readStoredUserIdForTests = () async {
      reads++;
      return null;
    };
    ErrorReporter.sendOverride = null;
    ErrorReporter.observer = null;
    addTearDown(() {
      ErrorReporter.readStoredUserIdForTests = null;
      SessionManager.instance.resetIdentityQueueForTests();
    });
    ErrorReporter.instance.report(
      message: 'no-destination',
      level: 'error',
      section: 'timeout',
    );
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 0);
  });
}
