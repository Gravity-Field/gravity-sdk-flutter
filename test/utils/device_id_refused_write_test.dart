import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Answers every write with `false`, as the Android plugin does when
/// `commit()` fails (for instance on a full disk).
class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;
}

/// Every request carries the device, so a device id the disk refused must not
/// turn into a failure of every call the SDK makes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getDevice keeps working with one id when the device id write is refused', () async {
    ErrorReporter.disableNetworkForTests = true;
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _RefusingStore();
    DeviceUtils.instance
      ..debugDevice = null
      ..deviceIdCache = null
      ..userAgentCache = 'refused-ua';

    final first = await DeviceUtils.instance.getDevice();
    final second = await DeviceUtils.instance.getDevice();

    expect(first.id, isNotEmpty);
    expect(second.id, first.id, reason: 'one process, one device id');
  });
}
