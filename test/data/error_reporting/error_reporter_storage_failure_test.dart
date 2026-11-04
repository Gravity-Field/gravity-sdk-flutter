import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _UnavailableStore extends InMemorySharedPreferencesStore {
  _UnavailableStore() : super.empty();

  @override
  Future<Map<String, Object>> getAllWithParameters(GetAllParameters parameters) async {
    throw StateError('storage unavailable');
  }
}

void main() {
  test('failed uid and device id reads still send once with a nonempty fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final original = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _UnavailableStore();
    final sent = <Map<String, dynamic>>[];
    ErrorReporter.sendOverride = sent.add;
    addTearDown(() {
      ErrorReporter.sendOverride = null;
      SharedPreferencesStorePlatform.instance = original;
    });

    void report() => ErrorReporter.instance.report(
      message: 'storage-failure',
      level: 'error',
      section: 'storage-test',
    );

    // Both reports wait for storage concurrently. Only the one dispatched
    // first should spend the deduplication budget, even with no usable uid.
    report();
    report();
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(1));
    expect(sent.single['uid'], 'no-uid');
    expect(sent.single['ses'], 'no-session');
    report();
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(1));
  });
}
