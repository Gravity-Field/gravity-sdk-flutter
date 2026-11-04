import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sessionManager = SessionManager.instance;

  setUp(() async {
    SessionManager.instance.resetIdentityQueueForTests();
    SharedPreferences.setMockInitialValues({});
    await sessionManager.resetSession();
  });

  test('an empty response uid preserves the cached uid and accepts the session', () async {
    await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);
    final writes = <String>[];
    final notified = <String?>[];
    SessionManager.beforeUserIdWrite = (uid) async => writes.add(uid);
    sessionManager.onUserIdChanged = notified.add;
    addTearDown(() {
      SessionManager.beforeUserIdWrite = null;
      sessionManager.onUserIdChanged = null;
    });

    await sessionManager.saveUser(null, const User(uid: '', ses: 's2'), sessionManager.generation);
    await Future<void>.delayed(Duration.zero);

    final user = await sessionManager.getUser(null);
    expect(user?.uid, 'u1');
    expect(user?.ses, 's2');
    expect(await Prefs.instance.getUserId(), 'u1');
    expect(writes, isEmpty);
    expect(notified, isEmpty);
  });

  test('an empty response uid does not overwrite the uid from an earlier launch', () async {
    await Prefs.instance.setUserId('stored-uid');

    await sessionManager.saveUser(null, const User(uid: '', ses: 's1'), sessionManager.generation);

    expect(sessionManager.userId, isNull);
    expect(await Prefs.instance.getUserId(), 'stored-uid');
    final user = await sessionManager.getUser(null);
    expect(user?.uid, 'stored-uid');
    expect(user?.ses, 's1');
  });

  test('sparse responses preserve the cached pair', () async {
    await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);

    for (final response in [null, const User(), const User(uid: '')]) {
      await sessionManager.saveUser(null, response, sessionManager.generation);
      final user = await sessionManager.getUser(null);
      expect(user?.uid, 'u1');
      expect(user?.ses, 's1');
    }
  });

  test('an empty response session replaces the cached session like native SDKs', () async {
    await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);

    await sessionManager.saveUser(null, const User(ses: ''), sessionManager.generation);

    final user = await sessionManager.getUser(null);
    expect(user?.uid, 'u1');
    expect(user?.ses, '');
  });

  test('a response uid without a session preserves the cached session', () async {
    await sessionManager.saveUser(null, const User(uid: 'u1', ses: 's1'), sessionManager.generation);

    await sessionManager.saveUser(null, const User(uid: 'u2'), sessionManager.generation);

    final user = await sessionManager.getUser(null);
    expect(user?.uid, 'u2');
    expect(user?.ses, 's1');
  });

  test('concurrent readers see complete pairs across a held user ID write', () async {
    await sessionManager.saveUser(null, const User(uid: 'old-uid', ses: 'old-ses'), sessionManager.generation);
    final reached = Completer<void>();
    final release = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) {
      reached.complete();
      return release.future;
    };
    addTearDown(() => SessionManager.beforeUserIdWrite = null);

    final snapshots = <User?>[];
    // A Zone can observe the cache when the uid notification is scheduled,
    // even if the runtime resumes chained futures in the same microtask.
    sessionManager.onUserIdChanged = (_) {};
    addTearDown(() => sessionManager.onUserIdChanged = null);
    final save = runZoned(
      () => sessionManager.saveUser(
        null,
        const User(uid: 'new-uid', ses: 'new-ses'),
        sessionManager.generation,
      ),
      zoneSpecification: ZoneSpecification(scheduleMicrotask: (self, parent, zone, callback) {
        snapshots.add(sessionManager.getCachedUser());
        parent.scheduleMicrotask(zone, callback);
      }),
    );
    await reached.future;
    try {
      snapshots.add(await sessionManager.getUser(null));
      expect(snapshots.last?.uid, 'old-uid');
      expect(snapshots.last?.ses, 'old-ses');
    } finally {
      release.complete();
    }

    final read = sessionManager.getUser(null);
    await save;
    snapshots.add(await read);
    snapshots.add(await sessionManager.getUser(null));
    expect(snapshots.last?.uid, 'new-uid');
    expect(snapshots.last?.ses, 'new-ses');
    for (final user in snapshots) {
      expect(
        (user?.uid, user?.ses),
        isIn([('old-uid', 'old-ses'), ('new-uid', 'new-ses')]),
        reason: 'one accepted response must publish its uid and session together',
      );
    }
  });

  test('a stale saveUser racing a reset cannot erase the newer generation uid', () async {
    final staleGen = sessionManager.generation;

    // All three run concurrently: the stale save suspends inside prefs, the
    // reset invalidates its generation mid-flight, the fresh save must win.
    final stale = sessionManager.saveUser(null, const User(uid: 'stale-uid', ses: 's0'), staleGen);
    final reset = sessionManager.resetSession();
    final fresh = sessionManager.saveUser(
      null,
      const User(uid: 'fresh-uid', ses: 's1'),
      sessionManager.generation,
    );
    await Future.wait([stale, reset, fresh]);

    expect(sessionManager.userId, 'fresh-uid');
    expect(sessionManager.sessionId, 's1');
    expect(await Prefs.instance.getUserId(), 'fresh-uid');
  });

  test('a stale saveUser alone leaves no uid behind', () async {
    final staleGen = sessionManager.generation;

    final stale = sessionManager.saveUser(null, const User(uid: 'stale-uid', ses: 's0'), staleGen);
    await sessionManager.resetSession();
    await stale;

    expect(sessionManager.userId, isNull);
    expect(await Prefs.instance.getUserId(), isNull);
  });
}
