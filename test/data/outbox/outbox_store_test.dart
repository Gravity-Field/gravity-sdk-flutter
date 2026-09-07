import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails the first read the way a missing platform plugin would, then behaves
/// like an empty store.
class _FlakyPrefs extends Prefs {
  _FlakyPrefs() : super.forTesting();

  int reads = 0;

  @override
  Future<String?> getOutbox() async {
    reads++;
    if (reads == 1) {
      throw MissingPluginException('no prefs plugin');
    }
    return null;
  }
}

/// Reads fine but loses its first write.
class _FailFirstWritePrefs extends Prefs {
  _FailFirstWritePrefs() : super.forTesting();

  int writes = 0;

  @override
  Future<void> setOutbox(String json) async {
    writes++;
    if (writes == 1) throw MissingPluginException('no prefs plugin');
    return super.setOutbox(json);
  }
}

void main() {
  final t0 = DateTime.utc(2026, 8, 28, 11);
  OutboxEntry entry(String id, {DateTime? createdAt}) =>
      OutboxEntry(id: id, kind: OutboxKind.event, createdAt: createdAt ?? t0, body: {'id': id});

  // A separate Prefs wrapper per store: `Prefs.instance` captured its
  // `SharedPreferences.getInstance()` future once, before these tests ran, so
  // it keeps reading that snapshot and would leak state between tests.
  OutboxStore newStore() => OutboxStore(prefs: Prefs.forTesting());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.instance.removeOutbox();
  });

  test('starts empty and persists appended entries in FIFO order', () async {
    final store = OutboxStore();
    await store.load();
    expect(store.isEmpty, isTrue);
    expect(store.head, isNull);

    await store.append(entry('a'), maxEntries: 10);
    await store.append(entry('b'), maxEntries: 10);
    expect(store.length, 2);
    expect(store.head!.id, 'a');

    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final list = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(list.map((e) => e['id']), ['a', 'b']);

    final reloaded = newStore();
    await reloaded.load();
    expect(reloaded.snapshot().map((e) => e.id), ['a', 'b']);
  });

  test('removeById and replace update disk', () async {
    final store = newStore();
    await store.load();
    await store.append(entry('a'), maxEntries: 10);
    await store.append(entry('b'), maxEntries: 10);

    await store.replace(store.head!.copyWith(attempts: 4));
    await store.removeById('b');

    final reloaded = newStore();
    await reloaded.load();
    expect(reloaded.length, 1);
    expect(reloaded.head!.id, 'a');
    expect(reloaded.head!.attempts, 4);
  });

  test('overflow drops the oldest entries and reports them', () async {
    final store = newStore();
    await store.load();
    await store.append(entry('a'), maxEntries: 2);
    await store.append(entry('b'), maxEntries: 2);
    final dropped = await store.append(entry('c'), maxEntries: 2);
    expect(dropped.map((e) => e.id), ['a']);
    expect(store.snapshot().map((e) => e.id), ['b', 'c']);
  });

  test('a maxEntries below 1 still keeps the appended entry', () async {
    final store = newStore();
    await store.load();
    final dropped = await store.append(entry('a'), maxEntries: 0);
    expect(dropped, isEmpty);
    expect(store.snapshot().length, 1);
    expect(store.snapshot().single.id, 'a');
  });

  test('pruneExpired removes entries older than maxAge', () async {
    final store = newStore();
    await store.load();
    await store.append(entry('old', createdAt: t0.subtract(const Duration(days: 8))), maxEntries: 10);
    await store.append(entry('fresh'), maxEntries: 10);
    final dropped = await store.pruneExpired(maxAge: const Duration(days: 7), now: t0);
    expect(dropped.map((e) => e.id), ['old']);
    expect(store.snapshot().map((e) => e.id), ['fresh']);
  });

  test('corrupt or foreign data on disk is discarded', () async {
    SharedPreferences.setMockInitialValues({'gravity_outbox': 'not json'});
    final store = newStore();
    await store.load();
    expect(store.isEmpty, isTrue);

    SharedPreferences.setMockInitialValues({
      'gravity_outbox': jsonEncode([
        {...entry('ok').toJson()},
        {...entry('bad').toJson(), 'v': 99},
        'garbage',
      ]),
    });
    final store2 = newStore();
    await store2.load();
    expect(store2.snapshot().map((e) => e.id), ['ok']);
  });

  test('a mutation before load() keeps what is already on disk', () async {
    SharedPreferences.setMockInitialValues({
      'gravity_outbox': jsonEncode([entry('persisted').toJson()]),
    });
    final store = OutboxStore(prefs: Prefs.forTesting());

    // No explicit load(): the mutation must read the queue first.
    await store.append(entry('new'), maxEntries: 10);

    expect(store.snapshot().map((e) => e.id), ['persisted', 'new']);
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final ids = (jsonDecode(raw!) as List).map((e) => (e as Map)['id']).toList();
    expect(ids, ['persisted', 'new']);
  });

  test('load is idempotent and concurrent mutations serialise on disk', () async {
    final store = newStore();
    await Future.wait([store.load(), store.load()]);
    await Future.wait([
      store.append(entry('a'), maxEntries: 10),
      store.append(entry('b'), maxEntries: 10),
      store.append(entry('c'), maxEntries: 10),
    ]);
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final ids = (jsonDecode(raw!) as List).map((e) => (e as Map)['id']).toList();
    expect(ids, ['a', 'b', 'c']);
  });

  test('a failed load is not memoised and the next load retries', () async {
    final prefs = _FlakyPrefs();
    final store = OutboxStore(prefs: prefs);

    await expectLater(store.load(), throwsA(isA<MissingPluginException>()));

    await store.load();
    expect(prefs.reads, 2);
    expect(store.isEmpty, isTrue);
  });

  test('a failed append does not roll back a concurrent append', () async {
    final prefs = _FailFirstWritePrefs();
    final store = OutboxStore(prefs: prefs);
    await store.load();

    final a = store.append(entry('a'), maxEntries: 10);
    final b = store.append(entry('b'), maxEntries: 10);
    await expectLater(a, throwsA(isA<MissingPluginException>()));
    await b;

    expect(store.snapshot().map((e) => e.id), ['b'], reason: "'a' never reached the disk, 'b' did");
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final list = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(list.map((e) => e['id']), ['b']);
  });
}
