import 'package:flutter/services.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BrokenPrefs extends Prefs {
  _BrokenPrefs({this.failRead = false}) : super.forTesting();
  final bool failRead;
  @override
  Future<String?> getOutbox() async {
    if (failRead) throw StateError('read unavailable');
    return null;
  }

  @override
  Future<void> setOutbox(String value) async =>
      throw PlatformException(code: 'write_unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OutboxStore store;
  late DateTime now;
  final originalClock = Clock.now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LoggerManager.instance.configure(LogLevel.none);
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    now = DateTime.utc(2026);
    Clock.now = () => now;
    store = OutboxStore(prefs: Prefs.forTesting());
  });
  tearDown(() {
    Clock.now = originalClock;
  });
  OutboxEntry entry(String id, {bool modal = false}) => OutboxEntry(
    id: id,
    kind: modal ? OutboxKind.engagement : OutboxKind.event,
    createdAt: now,
    url: modal ? 'https://example.test/WRIMP' : null,
    body: modal ? {'modalImpression': true} : {'event': id},
  );
  DioException error(int status) {
    final options = RequestOptions(path: '/engagement');
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status),
    );
  }

  for (final status in [408, 429, 503]) {
    test('WRIMP $status does not block an ordinary queued event', () async {
      final sent = <String>[];
      final dispatcher = OutboxDispatcher(
        store: store,
        settings: () => const OfflineQueueSettings(),
        sender: (entry) async {
          if (entry.isModalImpression) throw error(status);
          sent.add(entry.id);
        },
      );
      addTearDown(
        () => dispatcher.didChangeAppLifecycleState(AppLifecycleState.paused),
      );
      await store.append(entry('wrimp', modal: true), maxEntries: 10);
      await store.append(entry('purchase'), maxEntries: 10);
      await dispatcher.flush();
      expect(sent, ['purchase']);
      expect(store.snapshot().map((entry) => entry.id), ['wrimp']);
    });
  }
  test('overflow evicts optional entries before WRIMP', () async {
    await store.append(entry('wrimp', modal: true), maxEntries: 2);
    await store.append(entry('old-event'), maxEntries: 2);
    final dropped = await store.append(entry('new-event'), maxEntries: 2);
    expect(dropped.map((entry) => entry.id), ['old-event']);
    expect(store.snapshot().map((entry) => entry.id), ['wrimp', 'new-event']);
    expect((await store.pruneOverflow(maxEntries: 1)).single.id, 'new-event');
    expect(store.head!.id, 'wrimp');
    expect(
      (await store.append(entry('incoming-optional'), maxEntries: 1)).single.id,
      'incoming-optional',
    );
    expect(store.head!.id, 'wrimp');
  });
  test('new WRIMP bypasses a server backoff of an ordinary entry', () async {
    final sent = <String>[];
    final dispatcher = OutboxDispatcher(
      store: store,
      settings: () => const OfflineQueueSettings(),
      sender: (entry) async {
        sent.add(entry.id);
        if (!entry.isModalImpression) throw error(503);
      },
    );
    addTearDown(
      () => dispatcher.didChangeAppLifecycleState(AppLifecycleState.paused),
    );
    await store.append(entry('ordinary'), maxEntries: 10);
    await dispatcher.flush();
    await dispatcher.enqueue(entry('wrimp', modal: true));
    for (var i = 0; i < 30 && !sent.contains('wrimp'); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sent, contains('wrimp'));
  });
  test(
    'storage failure attempts original WRIMP online and read failure is fail-open',
    () async {
      final sent = <String>[];
      final dispatcher = OutboxDispatcher(
        store: OutboxStore(prefs: _BrokenPrefs()),
        settings: () => const OfflineQueueSettings(),
        sender: (entry) async {
          sent.add(entry.url!);
        },
      );
      expect(
        await dispatcher.deliverModal(entry('wrimp', modal: true)),
        isTrue,
      );
      expect(sent, ['https://example.test/WRIMP']);
      final unreadable = OutboxDispatcher(
        store: OutboxStore(prefs: _BrokenPrefs(failRead: true)),
        settings: () => const OfflineQueueSettings(),
        sender: (_) async {},
      );
      expect(await unreadable.load(), isFalse);
    },
  );
  test(
    'WRIMP survives protection expiry at 24 hours and is delivered until seven days',
    () async {
      final gate = InAppPresentationGate(now: () => now);
      final reservation = gate.reserve(
        's/u',
        'campaign',
        gate.beginRequest('/a', 1),
      )!;
      gate.visible(reservation);
      final wrimp = entry('wrimp', modal: true);
      await store.append(wrimp, maxEntries: 10);
      now = now.add(const Duration(hours: 24, seconds: 1));
      expect(
        gate.reserve(
          's/u',
          'campaign',
          gate.beginRequest('/b', 1),
          deliveryPending:
              now.difference(wrimp.createdAt) <
              InAppPresentationGate.pendingDeliveryProtection,
        ),
        isNotNull,
      );
      expect(
        await store.pruneExpired(maxAge: const Duration(hours: 1), now: now),
        isEmpty,
      );
      final reloaded = OutboxStore(prefs: Prefs.forTesting());
      await reloaded.load();
      expect(reloaded.head!.url, wrimp.url);
      now = wrimp.createdAt.add(const Duration(days: 7));
      expect(
        (await store.pruneExpired(
          maxAge: const Duration(days: 30),
          now: now,
        )).single.id,
        'wrimp',
      );
    },
  );
  test(
    'permanent modal rejection drops and releases its reservation immediately',
    () async {
      final gate = InAppPresentationGate(now: () => now);
      final reservation = gate.reserve(
        's/u',
        'campaign',
        gate.beginRequest('/a', 1),
      )!;
      gate.visible(reservation);
      final dispatcher = OutboxDispatcher(
        store: store,
        settings: () => const OfflineQueueSettings(),
        sender: (_) async {
          throw error(403);
        },
        onDropped: (_) => gate.rejected('s/u', 'campaign', reservation.token),
      );
      addTearDown(
        () => dispatcher.didChangeAppLifecycleState(AppLifecycleState.paused),
      );
      await dispatcher.deliverModal(entry('wrimp', modal: true));
      expect(await dispatcher.pendingCount, 0);
      expect(
        gate.reserve('s/u', 'campaign', gate.beginRequest('/b', 1)),
        isNotNull,
      );
    },
  );
  test(
    'persisted retry time survives store reload and ordinary events still flow',
    () async {
      var attempts = 0;
      final dispatcher = OutboxDispatcher(
        store: store,
        settings: () => const OfflineQueueSettings(),
        sender: (_) async {
          attempts++;
          throw error(503);
        },
      );
      await dispatcher.deliverModal(entry('wrimp', modal: true));
      dispatcher.didChangeAppLifecycleState(AppLifecycleState.paused);
      final reloaded = OutboxStore(prefs: Prefs.forTesting());
      await reloaded.load();
      expect(reloaded.head!.modalRetryAt, isNotNull);
      final sent = <String>[];
      final restarted = OutboxDispatcher(
        store: reloaded,
        settings: () => const OfflineQueueSettings(),
        sender: (e) async {
          sent.add(e.id);
        },
      );
      addTearDown(
        () => restarted.didChangeAppLifecycleState(AppLifecycleState.paused),
      );
      await restarted.start();
      await restarted.enqueue(entry('ordinary'));
      for (var i = 0; i < 30 && !sent.contains('ordinary'); i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sent, ['ordinary']);
      expect(attempts, 1);
      await restarted.flush();
      expect(sent, ['ordinary', 'wrimp']);
    },
  );
  test('corrupt outbox is reported without including stored payload', () async {
    final reports = <Map<String, dynamic>>[];
    ErrorReporter.observer = (section, payload) {
      if (section == 'OutboxStore.load') reports.add(payload);
    };
    addTearDown(() => ErrorReporter.observer = null);
    final prefs = Prefs.forTesting();
    await prefs.setOutbox('invalid-json PRIVATE-CONTEXT');
    final corrupt = OutboxStore(prefs: prefs);
    await corrupt.load();
    expect(corrupt.isEmpty, isTrue);
    expect(reports, hasLength(1));
    expect(reports.single['message'], isNot(contains('PRIVATE-CONTEXT')));
  });
}
