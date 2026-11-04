import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'initialize preserves preconfigured options and the uid listener across repeated calls',
    () async {
      SharedPreferences.setMockInitialValues({});
      OutboxDispatcher.lifecycleObserverEnabled = false;
      final sdk = GravitySDK.instance;
      final notified = <String?>[];
      sdk.setUserIdListener(notified.add);
      sdk.setOptions(
        isFetchContentOnTrack: false,
        staleContentTimeout: const Duration(seconds: 37),
      );
      try {
        await sdk.initialize(apiKey: 'first-key', section: 'first-section');
        expect(sdk.isFetchContentOnTrack, isFalse);
        expect(sdk.staleContentTimeout, const Duration(seconds: 37));
        await sdk.restoreUserId('first-uid');

        sdk.setOptions(staleContentTimeout: const Duration(seconds: 53));
        await sdk.initialize(apiKey: 'second-key', section: 'second-section');
        expect(sdk.isFetchContentOnTrack, isFalse);
        expect(sdk.staleContentTimeout, const Duration(seconds: 53));
        await sdk.restoreUserId('second-uid');
        await Future<void>.delayed(Duration.zero);
        expect(notified, ['first-uid', 'second-uid']);
      } finally {
        sdk.setUserIdListener(null);
        sdk.setOptions(
          isFetchContentOnTrack: true,
          staleContentTimeout: const Duration(seconds: 10),
        );
        await sdk.resetUser();
        OutboxDispatcher.lifecycleObserverEnabled = true;
      }
    },
  );
}
