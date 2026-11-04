import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.empty();

  int rejectUserIdWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_user_id') && rejectUserIdWrites > 0) {
      rejectUserIdWrites--;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  Future<String?> storedUserId() async => (await getAll())['flutter.gravity_user_id'] as String?;
}

void main() {
  final session = SessionManager.instance;
  late _RefusingStore store;
  late Completer<void> reached;
  late Completer<void> release;

  Future<void> save(User user) => session.saveUser(null, user, session.generation);

  void holdNextWrite() {
    reached = Completer<void>();
    release = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) {
      SessionManager.beforeUserIdWrite = null;
      reached.complete();
      return release.future;
    };
  }

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    store = _RefusingStore();
    SharedPreferencesStorePlatform.instance = store;
    ErrorReporter.disableNetworkForTests = true;
  });

  setUp(() async {
    SessionManager.instance.resetIdentityQueueForTests();
    store.rejectUserIdWrites = 0;
    await session.resetSession();
    await save(const User(uid: 'u1', ses: 's1'));
  });

  tearDown(() {
    SessionManager.beforeUserIdWrite = null;
    session.onUserIdChanged = null;
    ErrorReporter.observer = null;
  });

  test('a test-zone queue tail cannot block the next test reset', () async {
    await Future<void>.delayed(Duration.zero);
    // Like a disposed FakeAsync zone: retain callbacks without running them.
    final abandonedMicrotasks = <void Function()>[];
    runZoned(
      () {
        final abandonedWrite = Future<void>.microtask(() {});
        SessionManager.beforeUserIdWrite = (_) => abandonedWrite;
        unawaited(save(const User(uid: 'abandoned-uid', ses: 'abandoned-session')));
      },
      zoneSpecification: ZoneSpecification(
        scheduleMicrotask: (_, _, _, callback) => abandonedMicrotasks.add(callback),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(abandonedMicrotasks, isNotEmpty);
    SessionManager.beforeUserIdWrite = (_) => throw StateError('abandoned hook');

    session.resetIdentityQueueForTests();
    await session.resetSession().timeout(const Duration(seconds: 1));
    await save(const User(uid: 'fresh-uid', ses: 'fresh-session')).timeout(const Duration(seconds: 1));

    expect((session.userId, session.sessionId), ('fresh-uid', 'fresh-session'));
    expect(await store.storedUserId(), 'fresh-uid');
  });

  test(
    'a later response echoing the old uid wins over a held new uid response',
    () async {
      holdNextWrite();
      final first = save(const User(uid: 'u2', ses: 's2'));
      await reached.future;
      final later = save(const User(uid: 'u1', ses: 's3'));
      release.complete();
      await Future.wait([first, later]);

      final user = await session.getUser(null);
      expect((user?.uid, user?.ses), ('u1', 's3'));
      expect(await store.storedUserId(), 'u1');
    },
  );

  test('ses-only responses cannot keep moving a storage reader behind the queue', () async {
    await session.resetSession();
    await Prefs.instance.setUserId('stored-uid');
    var reads = 0;
    final user = await session.getUserAfterIdentityUpdates(readStoredUserId: () async {
      reads++;
      // A finite stand-in for a continuous stream: every storage read races
      // another accepted response, while the uid cache remains incomplete.
      if (reads <= 20) unawaited(save(User(ses: 'session-$reads')));
      return 'stored-uid';
    });

    expect(user.uid, 'stored-uid');
    expect(reads, 1, reason: 'later responses must queue behind this read');
    expect((await session.getUser(null))?.uid, 'stored-uid');
  });

  test('an event snapshot with only a cached session reads the original uid before reset', () async {
    await session.resetSession();
    await Prefs.instance.setUserId('stored-uid');
    await save(const User(ses: 'known-session'));
    expect(session.userId, isNull);
    expect(session.observedUser, isNull);

    final snapshot = session.snapshotEventUser(null);
    final reset = session.resetSession();
    final user = await snapshot;
    await reset;

    expect(user?.uid, 'stored-uid');
    expect(user?.ses, 'known-session');
    expect(await session.loadUserId(), isNull);
  });

  for (final (name, response) in <(String, User?)>[
    ('null user', null),
    ('empty user', const User()),
    ('empty uid', const User(uid: '')),
  ]) {
    test('a response without identity fields completes during a held write: $name', () async {
      holdNextWrite();
      final first = save(const User(uid: 'u2', ses: 's2'));
      await reached.future;
      try {
        await session.saveUser(null, response, session.generation).timeout(const Duration(seconds: 1));
        expect((session.userId, session.sessionId), ('u1', 's1'));
      } finally {
        release.complete();
        await first;
      }
      expect((session.userId, session.sessionId), ('u2', 's2'));
      expect(await store.storedUserId(), 'u2');
    });
  }

  test(
    'a ses-only response waits for a held write before releasing its session gate',
    () async {
      holdNextWrite();
      final first = save(const User(uid: 'u2', ses: 's2'));
      await reached.future;
      final gate = session.beginSessionInitialization();
      final later = save(
        const User(ses: 's3'),
      ).then((_) => session.completeSessionInitialization(gate));
      var waiterReleased = false;
      final waiter = session.getUser(null).then((user) {
        waiterReleased = true;
        return user;
      });
      late bool releasedWhileHeld;
      late User? heldPair;
      try {
        await Future<void>.delayed(Duration.zero);
        releasedWhileHeld = waiterReleased;
        heldPair = session.getCachedUser();
      } finally {
        release.complete();
        await Future.wait([first, later]);
      }

      final user = await waiter.timeout(const Duration(seconds: 2));
      expect(releasedWhileHeld, isFalse);
      expect((heldPair?.uid, heldPair?.ses), ('u1', 's1'));
      expect((user?.uid, user?.ses), ('u2', 's3'));
      expect(session.isInitializing, isFalse);
    },
  );

  test(
    'two ses-only responses behind a held write apply in arrival order',
    () async {
      holdNextWrite();
      final first = save(const User(uid: 'u2', ses: 's2'));
      await reached.future;
      final second = save(const User(ses: 's3'));
      final third = save(const User(uid: '', ses: 's4'));
      release.complete();
      await Future.wait([first, second, third]);

      final user = await session.getUser(null);
      expect((user?.uid, user?.ses), ('u2', 's4'));
    },
  );

  test(
    'two ses-only responses without a uid write apply in arrival order',
    () async {
      await Future.wait([
        save(const User(ses: 's2')),
        save(const User(ses: 's3')),
      ]);

      final user = await session.getUser(null);
      expect((user?.uid, user?.ses), ('u1', 's3'));
      expect(await store.storedUserId(), 'u1');
    },
  );

  for (final restore in [false, true]) {
    test(
      'a ${restore ? 'restore' : 'reset'} drops queued responses from the previous generation',
      () async {
        holdNextWrite();
        final first = save(const User(uid: 'u2', ses: 's2'));
        await reached.future;
        final oldGeneration = session.generation;
        final queued = save(const User(ses: 'stale-session'));
        final change = restore ? session.restoreUserId('restored') : session.resetSession();
        final stale = session.saveUser(
          null,
          const User(uid: 'stale', ses: 'stale'),
          oldGeneration,
        );
        release.complete();
        await Future.wait([first, queued, change, stale]);

        expect(session.userId, restore ? 'restored' : isNull);
        expect(session.sessionId, isNull);
        expect(await store.storedUserId(), restore ? 'restored' : isNull);
        await save(const User(uid: 'fresh', ses: 'fresh-session'));
        expect((session.userId, session.sessionId), ('fresh', 'fresh-session'));
      },
    );
  }

  test(
    'storage failure releases queued sessions and retries the next uid echo once',
    () async {
      final notified = <String?>[];
      final reports = <String>[];
      session.onUserIdChanged = notified.add;
      ErrorReporter.observer = (section, _) => reports.add(section);
      holdNextWrite();
      store.rejectUserIdWrites = 2;
      final first = save(const User(uid: 'u2', ses: 's2'));
      await reached.future;
      final gate = session.beginSessionInitialization();
      final later = save(
        const User(ses: 's3'),
      ).then((_) => session.completeSessionInitialization(gate));
      final waiter = session.getUser(null);
      release.complete();
      await Future.wait([first, later]).timeout(const Duration(seconds: 2));

      final user = await waiter.timeout(const Duration(seconds: 2));
      expect((user?.uid, user?.ses), ('u2', 's3'));
      expect(await store.storedUserId(), 'u1');
      expect(
        reports.where((section) => section == 'SessionManager.saveUser'),
        hasLength(1),
      );
      expect(notified, ['u2']);

      await save(const User(uid: 'u2', ses: 's4'));
      expect(await Prefs.instance.getUserId(), 'u2');
      expect(await store.storedUserId(), 'u2');
      expect((session.userId, session.sessionId), ('u2', 's4'));
      expect(notified, ['u2']);
      expect(session.isInitializing, isFalse);
    },
  );
}
