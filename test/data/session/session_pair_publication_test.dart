import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _HeldUserIdStore extends InMemorySharedPreferencesStore {
  _HeldUserIdStore() : super.empty();

  Completer<void>? reached;
  Completer<void>? release;
  bool rejectWrites = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_user_id')) {
      final held = release;
      if (held != null) {
        release = null;
        reached!.complete();
        await held.future;
      }
      if (rejectWrites) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final session = SessionManager.instance;
  late _HeldUserIdStore store;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    store = _HeldUserIdStore();
    SharedPreferencesStorePlatform.instance = store;
    ErrorReporter.disableNetworkForTests = true;
  });

  setUp(() async {
    SessionManager.instance.resetIdentityQueueForTests();
    store.rejectWrites = false;
    await session.resetSession();
  });

  for (final rejectWrite in [false, true]) {
    test('fallback readers see a complete pair when the held write is ${rejectWrite ? 'refused' : 'accepted'}', () async {
      await Prefs.instance.setUserId('stored-uid');
      await session.saveUser(null, const User(uid: '', ses: 'old-ses'), session.generation);
      expect(session.userId, isNull);
      expect((await session.getUser(null))?.uid, 'stored-uid');

      final release = Completer<void>();
      store.reached = Completer<void>();
      store.release = release;
      store.rejectWrites = rejectWrite;
      final save = session.saveUser(null, const User(uid: 'new-uid', ses: 'new-ses'), session.generation);
      final snapshots = <User?>[];
      late Future<User?> read;
      try {
        await store.reached!.future;
        // shared_preferences updates its own cache before the platform write
        // finishes. The SDK must not combine that value with the old session.
        expect(await Prefs.instance.getUserId(), 'new-uid');
        read = session.getUser(null).then((user) {
          snapshots.add(user);
          return user;
        });
        await Future<void>.delayed(Duration.zero);
      } finally {
        release.complete();
        await save;
      }
      snapshots.add(await read);
      snapshots.add(await session.getUser(null));

      for (final user in snapshots) {
        expect(
          (user?.uid, user?.ses),
          isIn([('stored-uid', 'old-ses'), ('new-uid', 'new-ses')]),
        );
      }
      expect(snapshots.last?.uid, 'new-uid');
      expect(snapshots.last?.ses, 'new-ses');
      expect(await Prefs.instance.getUserId(), rejectWrite ? 'stored-uid' : 'new-uid');
    });
  }
}
