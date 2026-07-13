import 'dart:convert';

import '../models/external/content_settings.dart';
import '../models/external/options.dart';
import '../models/external/page_context.dart';
import '../models/external/rt_rule.dart';
import '../models/external/user.dart';

/// Sorts map keys recursively so logically-equal structures serialise to the
/// same string; lists keep their order (it is semantic for rules). Values the
/// wire encoder would reject — non-string map keys, non-List iterables,
/// cycles — get type-tagged stand-ins, so a wire-invalid request cannot
/// accidentally share a key with a wire-valid one.
Object? _canonicalize(Object? value, [Set<Object?>? seen]) {
  if (value is Map || value is Iterable) {
    seen ??= Set.identity();
    if (!seen.add(value)) {
      return '__cycle__';
    }
    try {
      if (value is Map) {
        final entries = <String, Object?>{};
        for (final e in value.entries) {
          final key = e.key;
          entries[key is String ? key : '__nonstr__:${key.runtimeType}:$key'] = e.value;
        }
        final keys = entries.keys.toList()..sort();
        return {for (final k in keys) k: _canonicalize(entries[k], seen)};
      }
      final items = [for (final item in value as Iterable) _canonicalize(item, seen)];
      return value is List ? items : {'__iter__': '${value.runtimeType}', 'v': items};
    } finally {
      // A sub-object shared between siblings is not a cycle.
      seen.remove(value);
    }
  }
  return value;
}

// Must never throw inside schedule(): an invalid attribute value has to fail
// on the wire, reported, like it always did.
String _encode(Object? value) => jsonEncode(
  _canonicalize(value),
  toEncodable: (o) {
    // toJson-bearing objects encode like the wire does (generated toJson
    // leaves nested models as objects); anything else gets a tagged stand-in.
    try {
      return _canonicalize((o as dynamic).toJson());
    } on NoSuchMethodError {
      return '__nonjson__:${o.runtimeType}:$o';
    }
  },
);

/// `sel:<value>` / `cid:<value>` — type-prefixed so a selector value can never collide
/// with an equal campaignId value in keys, wave partitioning, or demux.
String chooseTypedIdentifier(Map<String, dynamic> data) {
  final selector = data['selector'] as String?;
  if (selector != null) {
    return 'sel:$selector';
  }
  final campaignId = data['campaignId'] as String?;
  if (campaignId != null) {
    return 'cid:$campaignId';
  }
  throw ArgumentError('A batched /choose request must carry a selector or a campaignId');
}

/// Full request identity — a scheduled /choose request may reuse another's
/// response only when every field that affects that response matches.
String chooseDedupKey(Map<String, dynamic> data) => _encode(<String, Object?>{
  'id': chooseTypedIdentifier(data),
  'ctx': (data['context'] as PageContext).toJson(),
  'opt': (data['options'] as Options).toJson(),
  'cs': (data['contentSettings'] as ContentSettings).toJson(),
  'usr': (data['user'] as User?)?.toJson(),
  'sesUsr': data['isSessionUser'] == true,
  // Session epoch: requests straddling a reset must not share one response.
  'gen': data['gen'],
  'rules': (data['rules'] as List<RtRule>?)?.map((r) => r.toJson()).toList(),
});

/// Envelope compatibility — requests sharing (user, ctx, options) can be
/// merged into one POST /choose, because those fields are sent once per call
/// while identifier/contentSettings/rules are sent per data[] item. device and
/// sec are process-global and resolved at POST time, so they are excluded.
String chooseGroupKey(Map<String, dynamic> data) => _encode(<String, Object?>{
  'ctx': (data['context'] as PageContext).toJson(),
  'opt': (data['options'] as Options).toJson(),
  'usr': (data['user'] as User?)?.toJson(),
  // Session adoption and user overrides apply per group and must never touch
  // a custom-user request, even one whose JSON matches the session user's.
  'sesUsr': data['isSessionUser'] == true,
});
