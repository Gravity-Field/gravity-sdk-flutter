import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// The platform answered the write with `false` (the Android plugin returns
/// the result of `commit()`), so nothing reached the disk.
class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;
}

void main() {
  test('a write the platform rejected is an error, not a silent success', () async {
    SharedPreferencesStorePlatform.instance = _RejectingStore();
    final prefs = Prefs.forTesting();
    await expectLater(prefs.setOutbox('[]'), throwsA(isA<StateError>()));
  });
}
