import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {
  test('defaults: enabled, 500 entries, 7 days', () {
    const s = OfflineQueueSettings();
    expect(s.enabled, isTrue);
    expect(s.maxEntries, 500);
    expect(s.maxAge, const Duration(days: 7));
  });

  test('setOptions stores queue settings and stale timeout', () {
    final sdk = GravitySDK.instance;
    expect(sdk.offlineQueue.enabled, isTrue);
    expect(sdk.staleContentTimeout, const Duration(seconds: 10));

    sdk.setOptions(
      offlineQueue: const OfflineQueueSettings(
        enabled: false,
        maxEntries: 10,
        maxAge: Duration(hours: 1),
      ),
      staleContentTimeout: const Duration(seconds: 3),
    );
    addTearDown(
      () => sdk.setOptions(
        offlineQueue: const OfflineQueueSettings(),
        staleContentTimeout: const Duration(seconds: 10),
      ),
    );

    expect(sdk.offlineQueue.enabled, isFalse);
    expect(sdk.offlineQueue.maxEntries, 10);
    expect(sdk.staleContentTimeout, const Duration(seconds: 3));
  });
}
