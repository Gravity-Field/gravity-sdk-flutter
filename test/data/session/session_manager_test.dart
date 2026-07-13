import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sessionManager = SessionManager.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sessionManager.resetSession();
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
