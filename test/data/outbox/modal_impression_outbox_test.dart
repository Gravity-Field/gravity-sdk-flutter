import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'offline modal stays protected until network restore drains its durable URL',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      LoggerManager.instance.configure(LogLevel.none);
      ErrorReporter.disableNetworkForTests = true;
      OutboxDispatcher.lifecycleObserverEnabled = false;
      var online = false;
      final delivered = <String>[];
      final store = OutboxStore(prefs: Prefs.forTesting());
      final gate = InAppPresentationGate();
      final first = gate.beginRequest('/one', 1);
      final reservation = gate.reserve('section/user', 'campaign', first)!;
      final dispatcher = OutboxDispatcher(
        store: store,
        settings: () => const OfflineQueueSettings(),
        sender: (entry) async {
          if (!online) throw const SocketException('offline');
          delivered.add(entry.url!);
          gate.acknowledged('section/user', 'campaign');
        },
      );
      addTearDown(
        () => dispatcher.didChangeAppLifecycleState(AppLifecycleState.paused),
      );
      gate.visible(reservation);
      const url = 'https://example.test/engagement?type=WRIMP&user=original';
      await dispatcher.enqueue(
        OutboxEntry(
          id: 'opening',
          kind: OutboxKind.engagement,
          createdAt: DateTime.now(),
          url: url,
          body: {'modalImpression': true},
        ),
      );
      await dispatcher.flush();
      expect(delivered, isEmpty);
      expect(await dispatcher.pendingCount, 1);
      final next = gate.beginRequest('/two', 1);
      expect(
        gate.reserve(
          'section/user',
          'campaign',
          next,
          deliveryPending: store.snapshot().any(
            (entry) => entry.isModalImpression,
          ),
        ),
        isNull,
      );
      final reloaded = OutboxStore(prefs: Prefs.forTesting());
      await reloaded.load();
      expect(reloaded.snapshot().single.url, url);
      online = true;
      dispatcher.onRequestSucceeded();
      await dispatcher.flush();
      expect(delivered, [url]);
      expect(await dispatcher.pendingCount, 0);
      expect(gate.reserve('section/user', 'campaign', next), isNull);
      expect(
        gate.reserve(
          'section/user',
          'campaign',
          gate.beginRequest('/three', 1),
        ),
        isNotNull,
      );
    },
  );
}
