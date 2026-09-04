import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live smoke check: the real /event endpoint accepts customProps and eventTime
/// on typed events, and cuid/cuidType/cart on a custom event.
///
///     GRAVITY_LIVE=1 fvm flutter test test/live/typed_event_props_live_smoke_test.dart
///
/// Credentials: `GRAVITY_LIVE_API_KEY` / `GRAVITY_LIVE_SECTION`, else the demo
/// section from `example/lib/main.dart`.
void main() {
  final env = Platform.environment;

  ({String apiKey, String section})? credentials() {
    final apiKey = env['GRAVITY_LIVE_API_KEY'];
    final section = env['GRAVITY_LIVE_SECTION'];
    if (apiKey != null && section != null) return (apiKey: apiKey, section: section);

    final example = File('example/lib/main.dart');
    if (!example.existsSync()) return null;
    final source = example.readAsStringSync();
    final key = RegExp(r"apiKey:\s*'([^']+)'").firstMatch(source)?.group(1);
    final sec = RegExp(r"section:\s*'([^']+)'").firstMatch(source)?.group(1);
    if (key == null || sec == null) return null;
    return (apiKey: key, section: sec);
  }

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'event-live',
      packageName: 'ai.gravityfield.eventlive',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'event-live-ua', id: 'event-live-device');
    ErrorReporter.disableNetworkForTests = true;
  });

  test('live /event accepts typed events with customProps/eventTime and a full custom event', () async {
    if (env['GRAVITY_LIVE'] != '1') {
      markTestSkipped('Set GRAVITY_LIVE=1 to hit the real backend.');
      return;
    }
    final creds = credentials();
    if (creds == null) {
      markTestSkipped('Set GRAVITY_LIVE_API_KEY and GRAVITY_LIVE_SECTION (example/lib/main.dart not found).');
      return;
    }
    await GravitySDK.instance.initialize(apiKey: creds.apiKey, section: creds.section);

    final events = <TriggerEvent>[
      AddToCartEvent(
        value: 99.5,
        productId: 'live-sku-1',
        quantity: 1,
        currency: 'RUB',
        customProps: const {'list': 'search'},
        eventTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      PurchaseEvent(
        uniqueTransactionId: 'live-${DateTime.now().millisecondsSinceEpoch}',
        value: 99.5,
        cart: const [CartItem(productId: 'live-sku-1', quantity: 1, itemPrice: 99.5)],
        customProps: const {'payment_type': 'card'},
      ),
      LoginEvent(cuid: 'live-user@example.com', cuidType: 'email', customProps: const {'loyalty_tier': 'gold'}),
      CustomEvent(
        type: 'sdk-live-loyalty-v1',
        name: 'SDK live loyalty',
        cuid: 'live-user@example.com',
        cuidType: 'email',
        cart: const [CartItem(productId: 'live-sku-1', quantity: 1, itemPrice: 99.5)],
        customProps: const {'points': '150'},
        eventTime: DateTime.now(),
      ),
    ];

    // Api throws on any non-2xx, so a returned response means the server
    // accepted every event in the batch.
    final response = await Api().event(
      events,
      null,
      const PageContext(type: ContextType.other, data: [], location: '/event-live'),
      const Options(),
    );
    // ignore: avoid_print
    print('server accepted ${events.length} events; campaigns triggered: ${response.campaigns.length}');
  });
}
