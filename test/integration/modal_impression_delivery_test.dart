import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'WRIMP persists before send, retries beyond five failures, reloads and keeps original user/key',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      ErrorReporter.disableNetworkForTests = true;
      OutboxDispatcher.lifecycleObserverEnabled = false;
      Api.retryDelays = const [];
      final requests = <({String url, String? auth})>[];
      var status = 503;
      var sawPersistedBeforeSend = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final stored = await Prefs.instance.getOutbox();
        sawPersistedBeforeSend = stored != null && (jsonDecode(stored) as List).isNotEmpty;
        requests.add((
          url: request.uri.toString(),
          auth: request.headers.value('authorization'),
        ));
        request.response.statusCode = status;
        await request.response.close();
      });
      final sdk = GravitySDK.instance;
      await sdk.initialize(
        apiKey: 'original-key',
        section: 'original-section',
        logLevel: LogLevel.none,
      );
      final repo = GravityRepo.instance;
      addTearDown(() async {
        repo.outbox.didChangeAppLifecycleState(AppLifecycleState.paused);
        await repo.outbox.clear();
        await server.close(force: true);
      });
      sdk.setOptions(offlineQueue: const OfflineQueueSettings(enabled: false));
      expect(
        await repo.outbox.enqueue(
          OutboxEntry(
            id: 'optional',
            kind: OutboxKind.event,
            createdAt: DateTime.now(),
            body: {
              'user': {'custom': 'original-user'},
            },
          ),
        ),
        isFalse,
      );
      sdk.setUser('original-user', 'session');
      final scope = GravityRepo.impressionScope(sdk.section, sdk.user);
      final url = 'http://127.0.0.1:${server.port}/engagement?type=WRIMP&user=original-user&eventId=frozen';
      expect(
        await repo.queueModalImpression(
          urls: [url],
          scope: scope,
          campaignId: 'campaign',
          user: sdk.user,
          section: sdk.section,
          apiKey: sdk.apiKey,
        ),
        isTrue,
      );
      for (var i = 0; i < 6; i++) {
        await repo.outbox.flush();
      }
      expect(sawPersistedBeforeSend, isTrue);
      expect(requests.length, greaterThanOrEqualTo(6));
      expect(repo.hasPendingImpression(scope, 'campaign'), isTrue);
      expect(await sdk.pendingDeliveries, 1);
      final originalNow = Clock.now;
      Clock.now = () => originalNow().add(const Duration(hours: 23));
      expect(
        repo.hasPendingImpression(scope, 'campaign'),
        isTrue,
        reason: 'persisted protection lasts until ack or 24h',
      );
      Clock.now = () => originalNow().add(const Duration(hours: 24, seconds: 1));
      try {
        expect(
          repo.hasPendingImpression(scope, 'campaign'),
          isFalse,
          reason: 'durable retry cannot extend local protection past 24 hours',
        );
      } finally {
        Clock.now = originalNow;
      }

      final gate = InAppPresentationGate.instance;
      final pendingRequest = gate.beginRequest('/a', 1);
      expect(
        gate.reserve(
          scope,
          'campaign',
          pendingRequest,
          deliveryPending: repo.hasPendingImpression(scope, 'campaign'),
        ),
        isNull,
      );
      expect(
        repo.hasPendingImpression(
          GravityRepo.impressionScope('other-section', sdk.user),
          'campaign',
        ),
        isFalse,
      );

      // Stop the first process's timer and construct the queue from storage as a
      // fresh SDK process would. No URL or identity is reconstructed from sdk.user.
      repo.outbox.didChangeAppLifecycleState(AppLifecycleState.paused);
      final reloaded = OutboxStore(prefs: Prefs.forTesting());
      await reloaded.load();
      expect(reloaded.snapshot().single.url, url);
      expect(
        reloaded.snapshot().single.body!['user']['custom'],
        'original-user',
      );
      await sdk.initialize(
        apiKey: 'new-key',
        section: 'new-section',
        logLevel: LogLevel.none,
      );
      sdk.setUser('new-user', 'new-session');
      status = 204;
      final restarted = OutboxDispatcher(
        store: reloaded,
        sender: repo.sendOutboxEntry,
        settings: () => const OfflineQueueSettings(),
      );
      await restarted.start();
      await restarted.flush();
      expect(await restarted.pendingCount, 0);
      expect(
        requests.last.url,
        '/engagement?type=WRIMP&user=original-user&eventId=frozen',
      );
      expect(
        requests.every((request) => request.auth == 'Bearer original-key'),
        isTrue,
      );
      expect(
        gate.reserve(scope, 'campaign', pendingRequest),
        isNull,
        reason: 'pre-ack request stays stale',
      );
      expect(
        gate.reserve(scope, 'campaign', gate.beginRequest('/a', 1)),
        isNotNull,
        reason: 'fresh page view uses server policy',
      );
      final emptyReload = OutboxStore(prefs: Prefs.forTesting());
      await emptyReload.load();
      expect(emptyReload.isEmpty, isTrue);
    },
  );
}
