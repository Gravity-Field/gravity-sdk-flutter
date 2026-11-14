import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/loopback_http_overrides.dart';

void main() {
  final sdk = GravitySDK.instance;
  late HttpServer server;
  var status = 400;
  var callbacks = 0;
  final paths = <String>[];
  final bodies = <Map<String, dynamic>>[];
  const context = PageContext(
    type: ContextType.other,
    data: [],
    location: '/release',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = LoopbackHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'release',
      packageName: 'release',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    DeviceUtils.instance.debugDevice = const Device(
      userAgent: 'release',
      id: 'device',
    );
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    GravityRepo.chooseBatchDelay = Duration.zero;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      bodies.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      paths.add(request.uri.path);
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'user': status == 200
              ? {'uid': 'accepted-uid', 'ses': 'accepted-session'}
              : {'uid': 'refused-uid', 'ses': 'refused-session'},
          'campaigns': [
            if (status != 200)
              {
                'campaignId': 'refused-campaign',
                'priority': 99,
                'trigger': 'view',
              },
          ],
          'data': [
            {
              'selector': 'slot',
              'payload': [
                {
                  'campaignId': 'refused-campaign',
                  'experienceId': 'e',
                  'variationId': 'v',
                  'decisionId': 'd',
                  'contents': [
                    {
                      'contentId': 'refused-content',
                      'contentType': 'native',
                      'deliveryMethod': 'inline',
                      'variables': {'elements': []},
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      await request.response.close();
    });
    await sdk.initialize(apiKey: 'test-key', section: 'test-section');
    sdk.setOptions(
      proxyUrl: 'http://127.0.0.1:${server.port}',
      offlineQueue: const OfflineQueueSettings(enabled: false),
    );
  });

  setUp(() async {
    await sdk.restoreUserId('original-uid');
    callbacks = 0;
    paths.clear();
    bodies.clear();
    sdk.gravityContentCallback = (_) => callbacks++;
    sdk.gravityEventCallback = (_) => callbacks++;
  });

  tearDownAll(() async {
    sdk.gravityContentCallback = null;
    sdk.gravityEventCallback = null;
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  test(
    'this fixture refuses non-loopback connections before transport',
    () async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      var transportAttempts = 0;
      // A tripwire prevents actual network I/O even if the guard regresses.
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        transportAttempts++;
        throw StateError('Unexpected transport attempt');
      };
      await expectLater(
        client.getUrl(Uri.parse('https://203.0.113.1/fixture')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'reason',
            contains('loopback'),
          ),
        ),
      );
      expect(transportAttempts, 0);
    },
  );

  final getters = <String, Future<Object?> Function()>{
    'selector': () =>
        sdk.getContentBySelector(selector: 'slot', pageContext: context),
    'group': () => sdk.getContentByGroup(group: 'slot', pageContext: context),
    'campaign': () =>
        sdk.getContentByCampaignId(campaignId: 'slot', pageContext: context),
    'selector details': () => sdk.getContentBySelectorWithDetails(
      selector: 'slot',
      pageContext: context,
    ),
    'campaign details': () => sdk.getContentByCampaignIdWithDetails(
      campaignId: 'slot',
      pageContext: context,
    ),
  };

  for (final getter in getters.entries) {
    test(
      '${getter.key} sends content settings under option, separately from envelope options',
      () async {
        status = 200;
        await getter.value();
        expect(paths, ['/choose']);
        final body = bodies.single;
        expect(body['options'], sdk.options.toJson());
        final item = (body['data'] as List).single as Map;
        expect(item['option'], sdk.contentSettings.toJson());
        expect(item.containsKey('options'), isFalse);
      },
    );
  }

  test(
    'standard event optional fields remain absent in an actual event request',
    () async {
      status = 200;
      final api = Api();
      final body = await api.buildEventBody(
        [
          AddToCartEvent(value: 1, productId: 'p', quantity: 1),
          RemoveFromCartEvent(value: 1, productId: 'p', quantity: 1),
          SyncCartEvent(value: 1),
          PurchaseEvent(
            uniqueTransactionId: 'transaction',
            value: 1,
            cart: const [],
          ),
          AddToWishlistEvent(value: 1, productId: 'p'),
          SignUpEvent(),
          LoginEvent(),
          LoginEvent(cuid: '', cuidType: 'null', hashedEmail: 'hash'),
        ],
        null,
        context,
        const Options(),
      );
      await api.postEventBody(body);
      expect(paths, ['/event']);
      final events = (bodies.single['data'] as List)
          .cast<Map<String, dynamic>>();
      expect(events, hasLength(8));
      for (final event in events) {
        expect(event.values, isNot(contains(null)));
        expect(event['eventTime'], isA<String>());
      }
      expect(events.last['cuid'], '');
      expect(events.last['cuidType'], 'null');
      expect(events.last['hashedEmail'], 'hash');
    },
  );

  Future<void> expectNextSuccessKeepsOriginalIdentity() async {
    status = 200;
    final response = await sdk.getContentBySelector(
      selector: 'slot',
      pageContext: context,
    );
    expect(response.data, hasLength(1));
    expect(paths, hasLength(2));
    expect(paths.last, '/choose');
    expect(
      bodies.last['user'],
      {'uid': 'original-uid'},
      reason: 'the refused UID and session must not enter the next request',
    );
    expect(await sdk.getUserId(), 'accepted-uid');
  }

  testWidgets(
    'public triggerEvent rejects a refused session and preserves optional fields on the next success',
    (tester) async {
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('host'));
            },
          ),
        ),
      );
      final events = [
        LoginEvent(),
        LoginEvent(cuid: '', cuidType: 'null', hashedEmail: 'hash'),
      ];
      await tester.runAsync(() async {
        status = 401;
        await sdk.triggerEvent(
          context: host,
          events: events,
          pageContext: context,
        );
        expect(paths, ['/event']);
        expect(callbacks, 0);
        expect(await sdk.getUserId(), 'original-uid');
        status = 200;
        await sdk.triggerEvent(
          context: host,
          events: events,
          pageContext: context,
        );
        expect(paths, ['/event', '/event']);
        expect(bodies.last['user'], {'uid': 'original-uid'});
        final sent = (bodies.last['data'] as List).cast<Map<String, dynamic>>();
        expect(sent, hasLength(2));
        expect(sent.first.containsKey('cuid'), isFalse);
        expect(sent.first.containsKey('cuidType'), isFalse);
        expect(sent.first.containsKey('hashedEmail'), isFalse);
        for (final event in sent) {
          expect(event.values, isNot(contains(null)));
          expect(event['eventTime'], isA<String>());
        }
        expect(sent.last['cuid'], '');
        expect(sent.last['cuidType'], 'null');
        expect(sent.last['hashedEmail'], 'hash');
        expect(await sdk.getUserId(), 'accepted-uid');
        expect(callbacks, 0, reason: 'successful tracking has no campaigns');
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final code in [302, 400, 401, 429, 500, 503]) {
    for (final getter in getters.entries) {
      test(
        '$code choose ${getter.key} rejects valid content and identity in failure body',
        () async {
          status = code;
          await expectLater(getter.value(), throwsA(anything));
          expect(await sdk.getUserId(), 'original-uid');
          expect(callbacks, 0);
          expect(paths, ['/choose']);
          await expectNextSuccessKeepsOriginalIdentity();
        },
      );
    }
    for (final event in [false, true]) {
      test(
        '$code ${event ? 'event' : 'visit'} rejects campaigns and identity in failure body',
        () async {
          status = code;
          final result = event
              ? await sdk.triggerEventNoShow(
                  events: [CustomEvent(type: 'custom-v1', name: 'release')],
                  pageContext: context,
                )
              : await sdk.trackViewNoShow(pageContext: context);
          expect(result, isNull);
          expect(await sdk.getUserId(), 'original-uid');
          expect(callbacks, 0);
          expect(paths, [event ? '/event' : '/visit']);
          await expectNextSuccessKeepsOriginalIdentity();
        },
      );
    }
  }
}
