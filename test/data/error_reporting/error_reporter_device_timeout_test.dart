import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _HungPreferences extends InMemorySharedPreferencesStore {
  _HungPreferences() : super.empty();
  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => Completer<Map<String, Object>>().future;
}

void main() {
  testWidgets(
    'flu-13 hung device fallback also times out and clears its pending hash',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _HungPreferences();
      var now = DateTime(2041);
      Clock.now = () => now;
      DeviceUtils.instance.deviceIdCache = null;
      ErrorReporter.readStoredUserIdForTests = () =>
          Completer<String?>().future;
      final sent = <Map<String, dynamic>>[];
      ErrorReporter.sendOverride = sent.add;
      addTearDown(() {
        ErrorReporter.sendOverride = null;
        ErrorReporter.readStoredUserIdForTests = null;
        Clock.now = DateTime.now;
        SharedPreferencesStorePlatform.instance = originalStore;
        SessionManager.instance.resetIdentityQueueForTests();
      });
      void report() => ErrorReporter.instance.report(
        message: 'hung-device',
        level: 'error',
        section: 'timeout',
      );
      report();
      await tester.pump(const Duration(seconds: 10));
      expect(sent.single['uid'], 'no-uid');
      now = now.add(const Duration(minutes: 2));
      report();
      await tester.pump(const Duration(seconds: 10));
      expect(sent, hasLength(2));
    },
  );
}
