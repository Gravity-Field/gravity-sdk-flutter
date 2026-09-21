import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// The very first read of the store fails, as on a device whose storage is
/// still busy during a cold start; every read after that works.
class _FailsFirstReadStore extends InMemorySharedPreferencesStore {
  _FailsFirstReadStore() : super.withData({'flutter.gravity_user_id': 'uid-on-disk'});

  int reads = 0;

  @override
  Future<Map<String, Object>> getAllWithParameters(GetAllParameters parameters) {
    reads++;
    if (reads == 1) {
      return Future<Map<String, Object>>.error(StateError('storage unavailable'));
    }
    return super.getAllWithParameters(parameters);
  }
}

/// One failed `SharedPreferences.getInstance()` must not disable persistence
/// for the rest of the process: the plugin itself forgets a failed attempt, so
/// the wrapper has to as well, on the very same instance.
void main() {
  test('the same Prefs recovers from a failed first load', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _FailsFirstReadStore();
    SharedPreferencesStorePlatform.instance = store;

    final prefs = Prefs.forTesting();

    await expectLater(prefs.getUserId(), throwsA(isA<StateError>()));
    expect(
      await prefs.getUserId(),
      'uid-on-disk',
      reason: 'a process restart must not be the only way back',
    );
    expect(store.reads, 2, reason: 'the successful load is cached, not repeated');

    await prefs.setUserId('uid-written-after-recovery');
    expect((await store.getAll())['flutter.gravity_user_id'], 'uid-written-after-recovery');
  });
}
