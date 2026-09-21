import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Answers the first [rejectWrites] writes and the first [rejectRemovals]
/// removals with `false`, as the Android plugin does when `commit()` fails,
/// and counts every call that reached the platform.
class _FlakyStore extends InMemorySharedPreferencesStore {
  _FlakyStore({Map<String, Object> data = const {}}) : super.withData(data);

  int rejectWrites = 0;
  int rejectRemovals = 0;
  int writeCalls = 0;
  int removeCalls = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writeCalls++;
    if (rejectWrites > 0) {
      rejectWrites--;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    removeCalls++;
    if (rejectRemovals > 0) {
      rejectRemovals--;
      return false;
    }
    return super.remove(key);
  }
}

/// The identity keys carry the promise the public API makes: resetUser() may
/// not report success while the uid is still on the device.
void main() {
  const key = 'flutter.gravity_user_id';

  Prefs prefsOver(_FlakyStore store) {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = store;
    return Prefs.forTesting();
  }

  test('a rejected uid write is tried once more and then lands', () async {
    final store = _FlakyStore()..rejectWrites = 1;
    final prefs = prefsOver(store);

    await prefs.setUserId('uid-1');

    expect(store.writeCalls, 2, reason: 'exactly one retry, not a loop');
    expect((await store.getAll())[key], 'uid-1', reason: 'the platform store really has it');
  });

  test('a uid write rejected twice is an error, not a silent success', () async {
    final store = _FlakyStore()..rejectWrites = 2;
    final prefs = prefsOver(store);

    await expectLater(prefs.setUserId('uid-1'), throwsA(isA<StateError>()));

    expect(store.writeCalls, 2);
    expect((await store.getAll()).containsKey(key), isFalse);
  });

  test('a rejected uid removal is tried once more and then wipes the key', () async {
    final store = _FlakyStore(data: {key: 'uid-1'})..rejectRemovals = 1;
    final prefs = prefsOver(store);

    await prefs.removeUserId();

    expect(store.removeCalls, 2, reason: 'exactly one retry, not a loop');
    expect((await store.getAll()).containsKey(key), isFalse, reason: 'gone from the platform store');
  });

  test('a uid removal rejected twice is an error, not a silent success', () async {
    final store = _FlakyStore(data: {key: 'uid-1'})..rejectRemovals = 2;
    final prefs = prefsOver(store);

    await expectLater(prefs.removeUserId(), throwsA(isA<StateError>()));

    expect(store.removeCalls, 2);
    expect((await store.getAll())[key], 'uid-1', reason: 'the uid the caller asked to drop is still there');
  });

  test('a refused device id write keeps the id for this process instead of failing', () async {
    final store = _FlakyStore()..rejectWrites = 2;
    final prefs = prefsOver(store);

    await prefs.setDeviceId('device-1');

    expect(store.writeCalls, 1, reason: 'best effort: no retry, no error');
    expect(await prefs.getDeviceId(), 'device-1', reason: 'requests go on with the id this process minted');
    expect((await store.getAll()).containsKey('flutter.gravity_device_id'), isFalse);
  });
}
