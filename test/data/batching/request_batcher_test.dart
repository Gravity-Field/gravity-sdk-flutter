import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/batching/request_batcher.dart';

String dedupKey(Map<String, dynamic> data) => '${data['id']}|${data['group']}';
String groupKey(Map<String, dynamic> data) => '${data['group']}';

Map<String, dynamic> req(String id, {String group = 'g'}) => {'id': id, 'group': group};

void main() {
  group('RequestBatcher with separate dedup and group keys', () {
    late List<List<Map<String, dynamic>>> executorCalls;
    late RequestBatcher<String> batcher;

    RequestBatcher<String> buildBatcher({
      Future<List<String>> Function(List<Map<String, dynamic>>)? executor,
    }) {
      return RequestBatcher<String>(
        batchExecutor: executor ??
            (batch) async {
              executorCalls.add(batch);
              return [for (final r in batch) 'res:${r['id']}'];
            },
        batchDelay: const Duration(milliseconds: 5),
        dedupKeyGenerator: dedupKey,
        groupKeyGenerator: groupKey,
      );
    }

    setUp(() {
      executorCalls = [];
      batcher = buildBatcher();
    });

    test('deduplicates identical requests into one executor entry and one shared result', () async {
      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('a'));

      final results = await Future.wait([f1, f2]);

      expect(executorCalls, hasLength(1));
      expect(executorCalls.single, hasLength(1));
      expect(results, ['res:a', 'res:a']);
    });

    test('does not deduplicate requests with different dedup keys', () async {
      final futures = [batcher.schedule(req('a')), batcher.schedule(req('b'))];

      await Future.wait(futures);

      expect(executorCalls.expand((c) => c), hasLength(2));
    });

    // Regression guard for d808164: when the dedup key equals the group key,
    // every group degenerates to a single request and merging never happens.
    test('merges different requests sharing a group key into ONE executor call', () async {
      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('b'));

      final results = await Future.wait([f1, f2]);

      expect(executorCalls, hasLength(1));
      expect(executorCalls.single.map((r) => r['id']), ['a', 'b']);
      expect(results, ['res:a', 'res:b']);
    });

    test('executes requests with different group keys as separate batches', () async {
      final f1 = batcher.schedule(req('a', group: 'g1'));
      final f2 = batcher.schedule(req('b', group: 'g2'));

      await Future.wait([f1, f2]);

      expect(executorCalls, hasLength(2));
      expect(executorCalls.every((c) => c.length == 1), isTrue);
    });

    test('fans out results to callers by index within the batch', () async {
      batcher = buildBatcher(
        executor: (batch) async => [for (final r in batch) 'idx:${batch.indexOf(r)}:${r['id']}'],
      );

      final f1 = batcher.schedule(req('first'));
      final f2 = batcher.schedule(req('second'));

      expect(await f1, 'idx:0:first');
      expect(await f2, 'idx:1:second');
    });

    test('completes every caller with an error on response count mismatch', () async {
      batcher = buildBatcher(executor: (batch) async => ['only-one']);

      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('b'));

      final e1 = expectLater(f1, throwsA(isA<Exception>()));
      final e2 = expectLater(f2, throwsA(isA<Exception>()));
      await Future.wait([e1, e2]);
    });

    test('completes every caller with the executor error when the executor throws', () async {
      batcher = buildBatcher(executor: (batch) async => throw StateError('boom'));

      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('b'));

      final e1 = expectLater(f1, throwsStateError);
      final e2 = expectLater(f2, throwsStateError);
      await Future.wait([e1, e2]);
    });

    test('a throwing group key generator fails only that request, not the whole flush', () async {
      batcher = RequestBatcher<String>(
        batchExecutor: (batch) async {
          executorCalls.add(batch);
          return [for (final r in batch) 'res:${r['id']}'];
        },
        batchDelay: const Duration(milliseconds: 5),
        dedupKeyGenerator: dedupKey,
        groupKeyGenerator: (data) {
          if (data['id'] == 'poison') throw StateError('bad group key');
          return groupKey(data);
        },
      );

      final f1 = batcher.schedule(req('a'));
      final fPoison = batcher.schedule(req('poison'));

      final poisoned = expectLater(fPoison, throwsStateError);
      expect(await f1, 'res:a');
      await poisoned;
      expect(executorCalls, hasLength(1));
      expect(executorCalls.single.map((r) => r['id']), ['a']);
    });

    test('a failing group leaves other groups in the same flush unaffected', () async {
      batcher = buildBatcher(
        executor: (batch) async {
          if (batch.first['group'] == 'bad') {
            throw StateError('bad group');
          }
          executorCalls.add(batch);
          return [for (final r in batch) 'res:${r['id']}'];
        },
      );

      final ok = batcher.schedule(req('a', group: 'ok'));
      final bad = batcher.schedule(req('b', group: 'bad'));

      final failed = expectLater(bad, throwsStateError);
      expect(await ok, 'res:a');
      await failed;
      expect(executorCalls.single.map((r) => r['id']), ['a']);
    });

    test('clear() completes pending requests with a StateError and cancels the flush', () async {
      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('b'));

      batcher.clear();

      final e1 = expectLater(f1, throwsStateError);
      final e2 = expectLater(f2, throwsStateError);
      await Future.wait([e1, e2]);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(executorCalls, isEmpty);
      expect(batcher.pendingCount, 0);
    });

    test('clear() during an in-flight flush aborts only requests scheduled after the snapshot', () async {
      final gate = Completer<void>();
      batcher = buildBatcher(
        executor: (batch) async {
          executorCalls.add(batch);
          await gate.future;
          return [for (final r in batch) 'res:${r['id']}'];
        },
      );

      final f1 = batcher.schedule(req('a'));
      while (executorCalls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final f2 = batcher.schedule(req('b'));

      batcher.clear();
      final aborted = expectLater(f2, throwsStateError);
      gate.complete();

      expect(await f1, 'res:a');
      await aborted;
      expect(executorCalls, hasLength(1));
    });

    test('requests scheduled during execution are flushed in a following batch', () async {
      final gate = Completer<void>();
      batcher = buildBatcher(
        executor: (batch) async {
          executorCalls.add(batch);
          if (executorCalls.length == 1) {
            await gate.future;
          }
          return [for (final r in batch) 'res:${r['id']}'];
        },
      );

      final f1 = batcher.schedule(req('a'));
      while (executorCalls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final f2 = batcher.schedule(req('b'));
      gate.complete();

      expect(await f1, 'res:a');
      expect(await f2, 'res:b');
      expect(executorCalls, hasLength(2));
    });
  });

  group('RequestBatcher legacy single-generator mode', () {
    test('uses the group key for dedup when no dedup key generator is provided', () async {
      final executorCalls = <List<Map<String, dynamic>>>[];
      final batcher = RequestBatcher<String>(
        batchExecutor: (batch) async {
          executorCalls.add(batch);
          return [for (final r in batch) 'res:${r['id']}'];
        },
        batchDelay: const Duration(milliseconds: 5),
        groupKeyGenerator: groupKey,
      );

      final f1 = batcher.schedule(req('a'));
      final f2 = batcher.schedule(req('b'));

      final results = await Future.wait([f1, f2]);

      expect(executorCalls, hasLength(1));
      expect(executorCalls.single, hasLength(1));
      expect(results, ['res:a', 'res:a']);
    });
  });
}
