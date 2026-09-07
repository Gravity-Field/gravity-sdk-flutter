import 'package:gravity_sdk/src/utils/time_format.dart';

enum OutboxKind { event, engagement, visit }

/// One deferred request persisted by the outbox.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.attempts = 0,
    this.body,
    this.url,
  });

  static const int schemaVersion = 1;

  final String id;
  final OutboxKind kind;

  /// UTC time the request was originally attempted.
  final DateTime createdAt;

  /// Number of server-side failures (408/429/5xx) seen so far.
  final int attempts;

  /// Frozen request body for [OutboxKind.event] and [OutboxKind.visit].
  final Map<String, dynamic>? body;

  /// Engagement URL for [OutboxKind.engagement].
  final String? url;

  OutboxEntry copyWith({int? attempts, Map<String, dynamic>? body}) => OutboxEntry(
    id: id,
    kind: kind,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    body: body ?? this.body,
    url: url,
  );

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'id': id,
    'kind': kind.name,
    'createdAt': formatEventTime(createdAt),
    'attempts': attempts,
    if (body != null) 'body': body,
    if (url != null) 'url': url,
  };

  /// Returns `null` for entries written by another schema version or with
  /// missing/invalid fields; such entries are skipped on load.
  static OutboxEntry? fromJson(Map<String, dynamic> json) {
    if (json['v'] != schemaVersion) return null;
    final id = json['id'];
    final kindName = json['kind'];
    final createdRaw = json['createdAt'];
    if (id is! String || kindName is! String || createdRaw is! String) {
      return null;
    }

    final kind = OutboxKind.values.cast<OutboxKind?>().firstWhere(
      (k) => k!.name == kindName,
      orElse: () => null,
    );
    if (kind == null) return null;

    final createdAt = DateTime.tryParse(createdRaw)?.toUtc();
    if (createdAt == null) return null;

    final body = json['body'];
    final url = json['url'];
    switch (kind) {
      case OutboxKind.event:
      case OutboxKind.visit:
        if (body is! Map<String, dynamic>) return null;
      case OutboxKind.engagement:
        if (url is! String) return null;
    }

    final attempts = json['attempts'];
    return OutboxEntry(
      id: id,
      kind: kind,
      createdAt: createdAt,
      attempts: attempts is int ? attempts : 0,
      body: body is Map<String, dynamic> ? body : null,
      url: url is String ? url : null,
    );
  }
}
