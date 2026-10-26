import 'dart:async';
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
import 'package:gravity_sdk/src/utils/content_events_service.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LoggerManager.instance.configure(LogLevel.none);
  final repo = GravityRepo.instance;
  final sdk = GravitySDK.instance;
  late HttpServer server;
  late String url;
  var status = 503;
  final requests = <String?>[];
  Completer<void>? holdResponse;

  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('condition not reached');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
  });

  setUp(() async {
    await repo.outbox.clear();
    requests.clear();
    status = 503;
    holdResponse = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url =
        'http://127.0.0.1:${server.port}/engagement?type=WRIMP&eventId=opaque-original-user';
    server.listen((request) async {
      requests.add(request.headers.value('authorization'));
      await holdResponse?.future;
      request.response.statusCode = status;
      await request.response.close();
    });
    await sdk.initialize(
      apiKey: 'private-api-key',
      section: 'private-section',
      logLevel: LogLevel.none,
    );
    sdk.user = const User(
      custom: 'private-email@example.test',
      ses: 'private-session',
      attributes: {'phone': 'private-phone'},
    );
  });

  tearDown(() async {
    if (holdResponse != null && !holdResponse!.isCompleted) {
      holdResponse!.complete();
    }
    await repo.outbox.flush();
    repo.outbox.didChangeAppLifecycleState(AppLifecycleState.paused);
    await repo.outbox.clear();
    sdk.gravityEventCallback = null;
    await server.close(force: true);
  });

  Campaign contentCampaign({bool withUrl = true}) => Campaign.fromJson({
    'payload': [
      {
        'campaignId': 'callback-campaign',
        'experienceId': 'e',
        'variationId': 'v',
        'decisionId': 'd',
        'contents': [
          {
            'contentId': 'window',
            'deliveryMethod': 'modal',
            'contentType': 'native',
            'variables': <String, dynamic>{},
            'events': [
              if (withUrl)
                {
                  'type': 'visible_impression',
                  'urls': [url],
                },
            ],
          },
        ],
      },
    ],
  });

  Future<void> queue({String? token}) async {
    await repo.queueModalImpression(
      urls: [url],
      scope: GravityRepo.impressionScope(sdk.section, sdk.user),
      campaignId: 'privacy-campaign',
      user: sdk.user,
      section: sdk.section,
      apiKey: sdk.apiKey,
      reservationToken: token,
    );
  }

  test(
    'persisted modal contains fingerprint and no key, user attributes or redundant identity',
    () async {
      await queue();
      final raw = (await Prefs.instance.getOutbox())!;
      final body = (jsonDecode(raw) as List).single['body'] as Map;
      expect(body['apiKeyFingerprint'], '6bb57354ef5ac749dbe3ef8d0a66989f35219c8e3dfa011234e2a26a9cec1827');
      for (final sensitive in [
        'private-api-key',
        'private-email',
        'private-session',
        'private-phone',
        'private-section',
      ]) {
        expect(raw, isNot(contains(sensitive)));
      }
      expect(body.containsKey('user'), isFalse);
      expect(body.containsKey('apiKey'), isFalse);
      expect(body['urls'], [url]);
    },
  );

  test(
    'changed API key drops queued modal without HTTP and releases protection',
    () async {
      final scope = GravityRepo.impressionScope(sdk.section, sdk.user);
      final gate = InAppPresentationGate.instance;
      final reservation = gate.reserve(
        scope,
        'privacy-campaign',
        gate.beginRequest('/privacy', 1234),
      )!;
      gate.visible(reservation);
      await queue(token: reservation.token);
      final before = requests.length;
      expect(repo.hasPendingImpression(scope, 'privacy-campaign'), isTrue);
      await sdk.initialize(
        apiKey: 'changed-key',
        section: 'new-section',
        logLevel: LogLevel.none,
      );
      await repo.outbox.flush();
      expect(requests.length, before);
      expect(await repo.outbox.pendingCount, 0);
      expect(repo.hasPendingImpression(scope, 'privacy-campaign'), isFalse);
      expect(gate.owns(reservation), isFalse);
      expect(
        gate.reserve(
          scope,
          'privacy-campaign',
          gate.beginRequest('/privacy', 1234),
        ),
        isNotNull,
      );
    },
  );

  test(
    'restart with a different key drops the saved fingerprint without replay',
    () async {
      await queue();
      repo.outbox.didChangeAppLifecycleState(AppLifecycleState.paused);
      final reloaded = OutboxStore(prefs: Prefs.forTesting());
      await reloaded.load();
      final before = requests.length;
      await sdk.initialize(
        apiKey: 'restart-key',
        section: 'restart-section',
        logLevel: LogLevel.none,
      );
      final restarted = OutboxDispatcher(
        store: reloaded,
        sender: repo.sendOutboxEntry,
        settings: () => const OfflineQueueSettings(),
      );
      addTearDown(
        () => restarted.didChangeAppLifecycleState(AppLifecycleState.paused),
      );
      await restarted.start();
      await restarted.flush();
      expect(requests.length, before);
      expect(await restarted.pendingCount, 0);
      final finalStore = OutboxStore(prefs: Prefs.forTesting());
      await finalStore.load();
      expect(finalStore.isEmpty, isTrue);
    },
  );

  test(
    'missing fingerprint is permanently dropped without sending as current user',
    () async {
      final scope = GravityRepo.impressionScope(sdk.section, sdk.user);
      final gate = InAppPresentationGate.instance;
      final reservation = gate.reserve(
        scope,
        'missing-fingerprint',
        gate.beginRequest('/missing', 1235),
      )!;
      gate.visible(reservation);
      await repo.outbox.deliverModal(
        OutboxEntry(
          id: 'missing-fingerprint',
          kind: OutboxKind.engagement,
          createdAt: DateTime.now(),
          url: url,
          body: {
            'modalImpression': true,
            'scope': scope,
            'campaignId': 'missing-fingerprint',
            'reservationToken': reservation.token,
            'urls': [url],
          },
        ),
      );
      expect(requests, isEmpty);
      expect(await repo.outbox.pendingCount, 0);
      expect(gate.owns(reservation), isFalse);
    },
  );

  test(
    'legacy plaintext modal is dropped and scrubbed on storage reload',
    () async {
      final legacy = OutboxEntry(
        id: 'legacy',
        kind: OutboxKind.engagement,
        createdAt: DateTime.now(),
        url: url,
        body: {
          'modalImpression': true,
          'apiKey': 'legacy-secret',
          'user': {
            'attributes': {'email': 'legacy-pii'},
          },
          'scope': 'legacy-user',
          'campaignId': 'legacy-campaign',
          'urls': [url],
        },
      );
      final ordinary = OutboxEntry(
        id: 'ordinary',
        kind: OutboxKind.event,
        createdAt: DateTime.now(),
        body: {'event': 'keep'},
      );
      await Prefs.instance.setOutbox(
        jsonEncode([legacy.toJson(), ordinary.toJson()]),
      );
      final store = OutboxStore(prefs: Prefs.forTesting());
      await store.load();
      expect(store.snapshot().map((entry) => entry.id), ['ordinary']);
      final raw = (await Prefs.instance.getOutbox())!;
      expect(raw, isNot(contains('legacy-secret')));
      expect(raw, isNot(contains('legacy-pii')));
      expect(requests, isEmpty);
    },
  );

  test(
    'appearance callback follows persistence and precedes a held HTTP response',
    () async {
      holdResponse = Completer<void>();
      var callbacks = 0;
      var persistedAtCallback = false;
      sdk.gravityEventCallback = (event) {
        if (event is ContentVisibleImpressionEvent) {
          callbacks++;
          persistedAtCallback = repo.outbox.snapshot.isNotEmpty;
        }
      };
      final campaign = contentCampaign();
      final opening = ContentEventsService.instance.createModalImpression(
        content: campaign.payload.first.contents.first,
        campaign: campaign,
      );
      opening.appeared();
      await waitFor(() => requests.isNotEmpty);
      expect(callbacks, 1);
      expect(persistedAtCallback, isTrue);
      expect(
        (jsonDecode((await Prefs.instance.getOutbox())!) as List),
        hasLength(1),
      );
      opening.appeared();
      opening.closed();
      holdResponse!.complete();
      await waitFor(() => repo.outbox.snapshot.single.attempts > 0);
      expect(callbacks, 1);
    },
  );

  test(
    'missing tracking URLs still notifies appearance exactly once',
    () async {
      var callbacks = 0;
      sdk.gravityEventCallback = (event) {
        if (event is ContentVisibleImpressionEvent) callbacks++;
      };
      final campaign = contentCampaign(withUrl: false);
      final opening = ContentEventsService.instance.createModalImpression(
        content: campaign.payload.first.contents.first,
        campaign: campaign,
      );
      opening.appeared();
      opening.appeared();
      await Future<void>.delayed(Duration.zero);
      expect(callbacks, 1);
      expect(requests, isEmpty);
    },
  );
}
