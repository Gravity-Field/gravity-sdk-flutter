import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/inline/inline_content.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Records the routes pushed onto the navigator it observes.
class _PushLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

/// In-app content resolved for one user on one screen is shown only if both
/// are still there once the answer (and the campaign's delay) is over: a
/// campaign of the previous user, or of a screen the user has left, is
/// dropped silently. Inline widgets ask again for the new user instead.
void main() {
  late HttpServer server;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final originalRetryDelays = Api.retryDelays;

  // Held answers: the SDK call is started, the test changes the world while
  // the server sits on the request, then lets it answer.
  var holdTriggers = false;
  var holdNextChoose = false;
  // The held /choose answers 500 instead of content.
  var failHeldChoose = false;
  final held = <Completer<void>>[];
  var delayTime = 0;
  var chooseAnswered = false;

  PageContext ctx() => const PageContext(type: ContextType.other, data: [], location: '/relevance');

  Map<String, dynamic> content(String contentId, String deliveryMethod) => {
    'contentId': contentId,
    'deliveryMethod': deliveryMethod,
    'contentType': 'native',
    'variables': {
      'frameUI': {
        'container': {
          'style': {'backgroundColor': '#ffffffff'},
        },
      },
      'elements': <Object>[],
    },
    'events': <Object>[],
  };

  Map<String, dynamic> campaign(String? selector, Map<String, dynamic> content) => {
    'selector': selector,
    'payload': [
      {
        'campaignId': 'camp-1',
        'experienceId': 'exp',
        'variationId': 'var',
        'decisionId': 'dec',
        'contents': [content],
      },
    ],
  };

  Future<void> waitFor(bool Function() condition, String reason) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail(reason);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void releaseHeld() {
    for (final gate in held) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'relevance-test',
      packageName: 'ai.gravityfield.relevancetest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'relevance-ua', id: 'relevance-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    VisibilityDetectorController.instance.updateInterval = Duration.zero;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      final isChoose = request.uri.path == '/choose';
      if ((!isChoose && holdTriggers) || (isChoose && holdNextChoose)) {
        if (isChoose) holdNextChoose = false;
        final gate = Completer<void>();
        held.add(gate);
        await gate.future;
        if (isChoose && failHeldChoose) {
          request.response.statusCode = 500;
          await request.response.close();
          chooseAnswered = true;
          return;
        }
      }
      request.response.headers.contentType = ContentType.json;
      if (isChoose) {
        final custom = (body['user'] as Map?)?['custom'] ?? 'anonymous';
        final items = (body['data'] as List).cast<Map<String, dynamic>>();
        request.response.write(jsonEncode({
          'user': {'uid': 'server-uid', 'ses': 'server-ses'},
          'data': [
            for (final item in items)
              if (item['campaignId'] != null)
                campaign(null, content('modal-for-$custom', 'modal'))
              else if (item['selector'] == 'anchor')
                campaign('anchor', content('anchor-for-$custom', 'modal'))
              else
                campaign(item['selector'] as String?, content('inline-for-$custom', 'inline')),
          ],
        }));
      } else {
        request.response.write(jsonEncode({
          'user': {'uid': 'server-uid', 'ses': 'server-ses'},
          'campaigns': [
            {'campaignId': 'camp-1', 'trigger': 'view', 'priority': 1, 'delayTime': delayTime},
          ],
        }));
      }
      await request.response.close();
      if (isChoose) chooseAnswered = true;
    });

    await GravitySDK.instance.initialize(apiKey: 'relevance-key', section: 'relevance-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
    Api.retryDelays = originalRetryDelays;
  });

  setUp(() async {
    await GravitySDK.instance.resetUser();
    recorded.clear();
    held.clear();
    holdTriggers = false;
    holdNextChoose = false;
    failHeldChoose = false;
    delayTime = 0;
    chooseAnswered = false;
  });

  tearDown(() {
    holdTriggers = false;
    holdNextChoose = false;
    releaseHeld();
  });

  group('in-app content', () {
    late GlobalKey<NavigatorState> rootKey;
    late GlobalKey<NavigatorState> nestedKey;
    late _PushLog pushLog;
    late BuildContext hostContext;
    // Routes the test pushes itself; any other dialog was opened by the SDK.
    late Set<Route<dynamic>> ownRoutes;

    bool shownBySdk() => pushLog.pushed.any((r) => r is DialogRoute && !ownRoutes.contains(r));

    Widget hostPage() => Builder(
      builder: (context) {
        hostContext = context;
        return const Text('Host route');
      },
    );

    Future<void> pumpHost(WidgetTester tester, {bool nested = false}) async {
      rootKey = GlobalKey<NavigatorState>();
      nestedKey = GlobalKey<NavigatorState>();
      pushLog = _PushLog();
      ownRoutes = {};
      // Drops the app, the SDK's dialog included, even when the test failed.
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootKey,
          navigatorObservers: [pushLog],
          home: nested
              ? Navigator(key: nestedKey, onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => hostPage()))
              : Scaffold(body: hostPage()),
        ),
      );
    }

    void pushOwn(WidgetTester tester, NavigatorState navigator) {
      final route = MaterialPageRoute<void>(builder: (_) => const Text('Screen B'));
      ownRoutes.add(route);
      unawaited(navigator.push(route));
    }

    Future<void> openHostDialog(WidgetTester tester) async {
      unawaited(showDialog<void>(context: hostContext, builder: (_) => const Text('Host dialog')));
      await tester.pump();
      ownRoutes.addAll(pushLog.pushed);
    }

    /// Starts [call], waits for its /visit or /event to reach the server,
    /// applies [change] while the answer is held, then lets it through.
    Future<void> changeWhileLoading(
      WidgetTester tester,
      Future<void> Function() call,
      FutureOr<void> Function() change,
    ) async {
      holdTriggers = true;
      await tester.runAsync(() async {
        final pending = call();
        await waitFor(() => held.isNotEmpty, 'the trigger request never arrived');
        await change();
        releaseHeld();
        await pending;
      });
    }

    Future<void> trackView() => GravitySDK.instance.trackView(context: hostContext, pageContext: ctx());

    Future<void> triggerEvent() => GravitySDK.instance.triggerEvent(
      context: hostContext,
      events: [CustomEvent(type: 'custom-v1', name: 'relevance')],
      pageContext: ctx(),
    );

    group('trackView', () {
      testWidgets('shows the campaign when nothing changed meanwhile', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, trackView, () {});
        expect(shownBySdk(), isTrue);
      });

      testWidgets('drops it when the user is reset during the campaign delay', (tester) async {
        await pumpHost(tester);
        delayTime = 400;
        await tester.runAsync(() async {
          final pending = trackView();
          await waitFor(() => chooseAnswered, 'the content request never finished');
          await GravitySDK.instance.resetUser();
          await pending;
        });
        expect(shownBySdk(), isFalse);
      });

      testWidgets('drops it when another user is set while loading', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, trackView, () => GravitySDK.instance.setUser('user-b', 'ses-b'));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('drops it when the app assigns the user field directly', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(
          tester,
          trackView,
          () => GravitySDK.instance.user = const User(custom: 'user-b', ses: 'ses-b'),
        );
        expect(shownBySdk(), isFalse);
      });

      testWidgets('shows it when the same user is set again', (tester) async {
        GravitySDK.instance.setUser('user-a', 'ses-a');
        await pumpHost(tester);
        await changeWhileLoading(tester, trackView, () => GravitySDK.instance.setUser('user-a', 'ses-a'));
        expect(shownBySdk(), isTrue);
      });

      testWidgets('drops it when another screen was pushed over the host', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, rootKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('shows it when the user came back to the host before the answer', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, trackView, () {
          pushOwn(tester, rootKey.currentState!);
          rootKey.currentState!.pop();
        });
        expect(shownBySdk(), isTrue);
      });

      testWidgets('drops it when a screen covers the route of a nested navigator', (tester) async {
        await pumpHost(tester, nested: true);
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, rootKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('shows it from under a host dialog that is still open', (tester) async {
        await pumpHost(tester);
        await openHostDialog(tester);
        await changeWhileLoading(tester, trackView, () {});
        expect(shownBySdk(), isTrue);
      });

      testWidgets('shows it from under a host dialog closed meanwhile', (tester) async {
        await pumpHost(tester);
        await openHostDialog(tester);
        await changeWhileLoading(tester, trackView, () => rootKey.currentState!.pop());
        expect(shownBySdk(), isTrue);
      });

      testWidgets('drops it when a screen was pushed over a host dialog', (tester) async {
        await pumpHost(tester);
        await openHostDialog(tester);
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, rootKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('with the navigator context, drops it when a screen was pushed', (tester) async {
        await pumpHost(tester);
        hostContext = rootKey.currentContext!;
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, rootKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('with a nested navigator context, drops it when that navigator moved on', (tester) async {
        await pumpHost(tester, nested: true);
        hostContext = nestedKey.currentContext!;
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, nestedKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('from under a host dialog, drops it when a nested navigator moved on', (tester) async {
        await pumpHost(tester, nested: true);
        await openHostDialog(tester);
        await changeWhileLoading(tester, trackView, () => pushOwn(tester, nestedKey.currentState!));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('with the navigator context, shows it when nothing changed', (tester) async {
        await pumpHost(tester);
        hostContext = rootKey.currentContext!;
        await changeWhileLoading(tester, trackView, () {});
        expect(shownBySdk(), isTrue);
      });
    });

    group('triggerEvent', () {
      testWidgets('drops it when another user is set while loading', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, triggerEvent, () => GravitySDK.instance.setUser('user-b', 'ses-b'));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('drops it when another screen was pushed over the host', (tester) async {
        await pumpHost(tester);
        await changeWhileLoading(tester, triggerEvent, () => pushOwn(tester, rootKey.currentState!));
        expect(shownBySdk(), isFalse);
      });
    });

    group('fetchAnchorContent', () {
      Future<void> fetchAnchor(WidgetTester tester, FutureOr<void> Function() change) async {
        holdNextChoose = true;
        await tester.runAsync(() async {
          final pending = GravitySDK.instance.fetchAnchorContent(
            context: hostContext,
            selector: 'anchor',
            pageContext: ctx(),
          );
          await waitFor(() => held.isNotEmpty, 'the content request never arrived');
          await change();
          releaseHeld();
          await pending;
        });
      }

      List<Map<String, dynamic>> chooseBodies() => [
        for (final r in recorded)
          if (r.path == '/choose') r.body,
      ];

      testWidgets('asks again for the user set while it was loading', (tester) async {
        await pumpHost(tester);
        await fetchAnchor(tester, () => GravitySDK.instance.setUser('user-b', 'ses-b'));

        final bodies = chooseBodies();
        expect(bodies, hasLength(2));
        expect((bodies.last['user'] as Map)['custom'], 'user-b');
        expect(shownBySdk(), isTrue);
      });

      testWidgets('asks again, unreported, when the request of the previous user failed', (tester) async {
        final sections = <String>[];
        ErrorReporter.observer = (section, _) => sections.add(section);
        addTearDown(() => ErrorReporter.observer = null);
        failHeldChoose = true;
        await pumpHost(tester);
        await fetchAnchor(tester, () => GravitySDK.instance.setUser('user-b', 'ses-b'));

        final bodies = chooseBodies();
        expect(bodies, hasLength(2));
        expect((bodies.last['user'] as Map)['custom'], 'user-b');
        expect(shownBySdk(), isTrue);
        expect(sections, isNot(contains('GravitySDK.fetchAnchorContent')));
      });

      testWidgets('neither asks again nor shows it once the screen changed as well', (tester) async {
        await pumpHost(tester);
        await fetchAnchor(tester, () {
          GravitySDK.instance.setUser('user-b', 'ses-b');
          pushOwn(tester, rootKey.currentState!);
        });

        expect(chooseBodies(), hasLength(1));
        expect(shownBySdk(), isFalse);
      });

      testWidgets('shows it when nothing changed meanwhile', (tester) async {
        await pumpHost(tester);
        await fetchAnchor(tester, () {});
        expect(shownBySdk(), isTrue);
      });
    });
  });

  group('inline widgets', () {
    /// Lets real I/O and the fake-async frame clock take turns until
    /// [condition] holds.
    Future<void> drive(WidgetTester tester, bool Function() condition, String reason) async {
      for (var i = 0; i < 200; i++) {
        if (condition()) return;
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      fail(reason);
    }

    List<Map<String, dynamic>> chooseBodies() => [
      for (final r in recorded)
        if (r.path == '/choose') r.body,
    ];

    String? shownContentId(WidgetTester tester) {
      final shown = find.byType(InlineContent);
      if (shown.evaluate().isEmpty) return null;
      return tester.widget<InlineContent>(shown.first).content.contentId;
    }

    /// Mounts [widget], sets another user while its first request is held,
    /// and returns the content requests it made and the content it shows.
    Future<({List<Map<String, dynamic>> requests, String? shown})> loadAcrossUserChange(
      WidgetTester tester,
      Widget widget, {
      bool firstRequestFails = false,
    }) async {
      holdNextChoose = true;
      failHeldChoose = firstRequestFails;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      await drive(tester, () => held.isNotEmpty, 'the first content request never arrived');

      GravitySDK.instance.setUser('user-b', 'ses-b');
      releaseHeld();

      await drive(tester, () => shownContentId(tester) != null, 'no inline content was shown');
      final result = (requests: chooseBodies(), shown: shownContentId(tester));

      await tester.pumpWidget(const SizedBox());
      // The widget's requests went out from the fake-async zone of this test,
      // and so did the session write that followed their answers. A later
      // write chains onto that one, and a future of a zone that is gone never
      // calls back: reset the user here, where pumping still reaches it, so
      // that the chain ends in the real zone before the test does.
      late Future<void> reset;
      await tester.runAsync(() async => reset = GravitySDK.instance.resetUser());
      await tester.pump();
      await tester.runAsync(() => reset);
      // The idle timer of the keep-alive connection lives there too.
      await tester.pump(const Duration(seconds: 30));
      return result;
    }

    testWidgets('GravityInlineWidget asks again for the user set while it was loading', (tester) async {
      final result = await loadAcrossUserChange(
        tester,
        GravityInlineWidget(selector: 'inline', pageContext: ctx()),
      );

      expect(result.requests, hasLength(2));
      expect((result.requests.last['user'] as Map)['custom'], 'user-b');
      expect(result.shown, 'inline-for-user-b');
    });

    testWidgets('GravityInlineListWidget asks again for the user set while it was loading', (tester) async {
      final result = await loadAcrossUserChange(
        tester,
        GravityInlineListWidget(group: 'inline-group', pageContext: ctx()),
      );

      expect(result.requests, hasLength(2));
      expect((result.requests.last['user'] as Map)['custom'], 'user-b');
      expect(result.shown, 'inline-for-user-b');
    });

    testWidgets('GravityInlineWidget asks again when the request of the previous user failed', (tester) async {
      final result = await loadAcrossUserChange(
        tester,
        GravityInlineWidget(selector: 'inline', pageContext: ctx()),
        firstRequestFails: true,
      );

      expect(result.requests, hasLength(2));
      expect((result.requests.last['user'] as Map)['custom'], 'user-b');
      expect(result.shown, 'inline-for-user-b');
    });

    testWidgets('GravityInlineListWidget asks again when the request of the previous user failed', (tester) async {
      final result = await loadAcrossUserChange(
        tester,
        GravityInlineListWidget(group: 'inline-group', pageContext: ctx()),
        firstRequestFails: true,
      );

      expect(result.requests, hasLength(2));
      expect((result.requests.last['user'] as Map)['custom'], 'user-b');
      expect(result.shown, 'inline-for-user-b');
    });
  });
}
