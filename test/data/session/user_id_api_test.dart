import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the awaited chain of microtasks settle without touching timers.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  final sessionManager = SessionManager.instance;
  final sdk = GravitySDK.instance;
  final notified = <String?>[];

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    sessionManager.onUserIdChanged = null;
    SessionManager.beforeUserIdWrite = null;
    await sessionManager.resetSession();
    sessionManager.onUserIdChanged = notified.add;
    notified.clear();
  });

  tearDown(() {
    sessionManager.onUserIdChanged = null;
    SessionManager.beforeUserIdWrite = null;
    sdk.user = null;
  });

  group('getUserId', () {
    test('cold start: uid stored in prefs and no cache is returned', () async {
      await Prefs.instance.setUserId('cold-uid');
      expect(sessionManager.userId, isNull);

      expect(await sdk.getUserId(), 'cold-uid');
    });

    test('waits for the session gate and returns the server uid', () async {
      final gate = sessionManager.beginSessionInitialization();
      var done = false;
      final read = sdk.getUserId().then((uid) {
        done = true;
        return uid;
      });
      await _settle();
      expect(done, isFalse, reason: 'must park behind the initialization');

      await sessionManager.saveUser(null, const User(uid: 'server-uid', ses: 's1'), sessionManager.generation);
      sessionManager.completeSessionInitialization(gate);

      expect(await read, 'server-uid');
    });

    test('a gate that fails after restoreUserId does not poison the reader', () async {
      final oldGate = sessionManager.beginSessionInitialization();
      final read = sdk.getUserId();
      await _settle();

      await sdk.restoreUserId('restored-uid');
      sessionManager.failSessionInitialization(oldGate, StateError('old owner failed'), StackTrace.current);

      expect(await read, 'restored-uid');
    });

    test('a gate of the same generation that fails is rethrown', () async {
      final gate = sessionManager.beginSessionInitialization();
      final read = sdk.getUserId();
      await _settle();

      sessionManager.failSessionInitialization(gate, StateError('owner failed'), StackTrace.current);

      await expectLater(read, throwsA(isA<StateError>()));
    });

    test('restore releases an existing uid reader before the old owner answers', () async {
      final oldOwner = sessionManager.beginSessionInitialization();
      var completed = false;
      final read = sdk.getUserId().then((uid) {
        completed = true;
        return uid;
      });
      await _settle();

      try {
        await sdk.restoreUserId('restored-uid');
        await _settle();
        expect(completed, isTrue, reason: 'the restored identity must not wait for the obsolete HTTP response');
        expect(await read, 'restored-uid');
      } finally {
        sessionManager.completeSessionInitialization(oldOwner);
        await read;
      }
    });

    test('a late failure of the old owner after a restore is neither rethrown nor unhandled', () async {
      final oldOwner = sessionManager.beginSessionInitialization();
      final read = sdk.getUserId();
      await _settle();

      await sdk.restoreUserId('restored-uid');
      expect(await read, 'restored-uid');

      // The reader has left; the old owner fails afterwards. A zone error here
      // would fail this test.
      sessionManager.failSessionInitialization(oldOwner, StateError('old owner failed late'), StackTrace.current);
      await _settle();
      await _settle();
      expect(await sdk.getUserId(), 'restored-uid');
    });

    test('old gate completing while the restore write is held keeps the reader waiting', () async {
      await Prefs.instance.setUserId('old-uid');
      final oldGate = sessionManager.beginSessionInitialization();
      final read = sdk.getUserId();
      await _settle();

      final hold = Completer<void>();
      SessionManager.beforeUserIdWrite = (_) => hold.future;
      final restore = sdk.restoreUserId('restored-uid');
      await _settle();

      var done = false;
      unawaited(read.then((_) => done = true));
      sessionManager.completeSessionInitialization(oldGate);
      await _settle();
      await _settle();
      expect(done, isFalse, reason: 'must wait for the restore gate, not read prefs');

      hold.complete();
      await restore;
      expect(await read, 'restored-uid');
    });
  });

  group('onUserIdChanged', () {
    test('fires once for a new uid, not for the same uid, null on reset, uid on restore', () async {
      await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);
      await _settle();
      expect(notified, ['u1']);

      await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's2'), sessionManager.generation);
      await _settle();
      expect(notified, ['u1']);

      await sessionManager.resetSession();
      await _settle();
      expect(notified, ['u1', null]);

      await sdk.restoreUserId('u2');
      await _settle();
      expect(notified, ['u1', null, 'u2']);
    });

    test('restore(R) followed by a server answer with R notifies once', () async {
      await sdk.restoreUserId('r');
      await sessionManager.saveUser(null, const User(uid: 'r', ses: 's1'), sessionManager.generation);
      await _settle();
      expect(notified, ['r']);
      expect(sessionManager.sessionId, 's1');
    });

    test('two concurrent saveUser with the same uid notify once', () async {
      final gen = sessionManager.generation;
      await Future.wait([
        sessionManager.saveUser(null, const User(uid: 'r', ses: 's1'), gen),
        sessionManager.saveUser(null, const User(uid: 'r', ses: 's1'), gen),
      ]);
      await _settle();
      expect(notified, ['r']);
    });

    test('cold start with R in prefs and a server answer with R notifies once', () async {
      await Prefs.instance.setUserId('r');
      expect(await sdk.getUserId(), 'r');
      await _settle();
      expect(notified, isEmpty, reason: 'reading is not a change');

      await sessionManager.saveUser(null, const User(uid: 'r', ses: 's1'), sessionManager.generation);
      await _settle();
      expect(notified, ['r']);
    });

    test('reset notifies null when a cold-start uid existed only in Prefs', () async {
      await Prefs.instance.setUserId('previous-launch-uid');
      expect(await sdk.getUserId(), 'previous-launch-uid');
      await _settle();
      expect(notified, isEmpty, reason: 'reading alone is not a notification');

      await sdk.resetUser();
      await _settle();

      expect(await sdk.getUserId(), isNull);
      expect(notified, <String?>[null], reason: 'a persisted uid was removed; an external backup must be cleared too');
    });

    test('reset with nothing stored and nothing reported stays silent', () async {
      await sdk.resetUser();
      await _settle();
      expect(notified, isEmpty);
    });

    test('restoring the same uid twice notifies once', () async {
      await sdk.restoreUserId('r');
      await sdk.restoreUserId('r');
      await _settle();
      expect(notified, ['r']);
    });
  });

  group('restoreUserId', () {
    test('a stale saveUser held inside the write cannot overwrite the restored uid', () async {
      final staleGen = sessionManager.generation;
      final hold = Completer<void>();
      SessionManager.beforeUserIdWrite = (uid) => uid == 'stale-uid' ? hold.future : Future.value();

      final stale = sessionManager.saveUser(null, const User(uid: 'stale-uid', ses: 's0'), staleGen);
      await _settle();
      final restore = sdk.restoreUserId('restored-uid');
      await _settle();
      hold.complete();
      await Future.wait([stale, restore]);

      expect(await Prefs.instance.getUserId(), 'restored-uid');
      expect(await sdk.getUserId(), 'restored-uid');
      expect(sessionManager.userId, 'restored-uid');
      expect(sessionManager.sessionId, isNull);
    });

    test('leaves no session, but a cached identity with the restored uid', () async {
      await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);

      await sdk.restoreUserId('restored-uid');

      expect(sessionManager.hasSession, isFalse);
      expect(sessionManager.isInitializing, isFalse);
      final cached = sessionManager.getCachedUser();
      expect(cached?.uid, 'restored-uid');
      expect(cached?.ses, isNull);
      final user = await sessionManager.getUser(null);
      expect(user?.uid, 'restored-uid');
      expect(user?.ses, isNull);
    });

    test('drops a custom user set via setUser', () async {
      sdk.setUser('custom-id', 'custom-ses');

      await sdk.restoreUserId('restored-uid');

      expect(sdk.user, isNull);
      expect(await sdk.getUserId(), 'restored-uid');
    });

    test('rejects an empty uid', () async {
      await expectLater(sdk.restoreUserId(''), throwsArgumentError);
      expect(await sdk.getUserId(), isNull);
    });
  });
}
