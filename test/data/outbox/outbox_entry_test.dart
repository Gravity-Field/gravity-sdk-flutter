import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';

void main() {
  final created = DateTime.utc(2026, 8, 28, 11, 0, 0, 123);

  test('event entry round-trips through JSON', () {
    final entry = OutboxEntry(
      id: 'id-1',
      kind: OutboxKind.event,
      createdAt: created,
      attempts: 2,
      body: {
        'sec': 's',
        'data': [
          {'type': 't', 'eventTime': '2026-08-28T11:00:00.123Z'},
        ],
      },
    );
    final json = jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>;
    expect(json['v'], OutboxEntry.schemaVersion);
    expect(json['kind'], 'event');
    expect(json['createdAt'], '2026-08-28T11:00:00.123Z');
    expect(json.containsKey('url'), isFalse);

    final back = OutboxEntry.fromJson(json)!;
    expect(back.id, 'id-1');
    expect(back.kind, OutboxKind.event);
    expect(back.createdAt, created);
    expect(back.createdAt.isUtc, isTrue);
    expect(back.attempts, 2);
    expect(back.body, entry.body);
    expect(back.url, isNull);
  });

  test('engagement entry keeps the url and has no body', () {
    final entry = OutboxEntry(
      id: 'id-2',
      kind: OutboxKind.engagement,
      createdAt: created,
      url: 'https://x/y',
    );
    final back = OutboxEntry.fromJson(entry.toJson())!;
    expect(back.url, 'https://x/y');
    expect(back.body, isNull);
    expect(entry.toJson().containsKey('body'), isFalse);
  });

  test('unknown schema version, unknown kind or missing fields -> null', () {
    final good = OutboxEntry(
      id: 'id',
      kind: OutboxKind.event,
      createdAt: created,
      body: {},
    ).toJson();
    expect(OutboxEntry.fromJson({...good, 'v': 99}), isNull);
    expect(OutboxEntry.fromJson({...good, 'kind': 'teleport'}), isNull);
    expect(OutboxEntry.fromJson({...good}..remove('id')), isNull);
    expect(OutboxEntry.fromJson({...good, 'createdAt': 'not-a-date'}), isNull);
    expect(
      OutboxEntry.fromJson({...good}..remove('body')),
      isNull,
      reason: 'event needs a body',
    );
    expect(
      OutboxEntry.fromJson({...good, 'kind': 'engagement'}..remove('body')),
      isNull,
      reason: 'engagement needs a url',
    );
  });

  test('copyWith changes attempts only', () {
    final entry = OutboxEntry(
      id: 'id',
      kind: OutboxKind.event,
      createdAt: created,
      body: {'a': 1},
    );
    final bumped = entry.copyWith(attempts: 3);
    expect(bumped.attempts, 3);
    expect(bumped.id, 'id');
    expect(bumped.body, {'a': 1});
    expect(entry.attempts, 0);
  });
}
