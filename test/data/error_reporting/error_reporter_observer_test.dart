import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

/// The observer is a test seam that sits on the path of every report. It may
/// neither see a payload it could rewrite on its way out nor, by throwing,
/// decide that the report is not worth sending.
void main() {
  tearDown(() {
    ErrorReporter.observer = null;
    ErrorReporter.sendOverride = null;
  });

  test('the observer is handed a payload it cannot rewrite', () {
    Map<String, dynamic>? seen;
    ErrorReporter.observer = (_, payload) => seen = payload;

    ErrorReporter.instance.report(
      message: 'immutable-payload-probe',
      level: 'warning',
      section: 'ObserverTest.immutable',
    );

    expect(seen, isNotNull);
    expect(() => seen!['level'] = 'error', throwsUnsupportedError);
    expect(() => seen!.remove('message'), throwsUnsupportedError);
  });

  test('the observer cannot reach the tags and extra of the caller', () {
    final tags = <String, String>{'category': 'session'};
    final extra = <String, dynamic>{'attempts': <int>[1]};
    final sent = <Map<String, dynamic>>[];
    ErrorReporter.sendOverride = sent.add;
    final rejected = <String>[];
    ErrorReporter.observer = (_, payload) {
      try {
        (payload['tags'] as Map)['category'] = 'rewritten';
      } on UnsupportedError {
        rejected.add('tags');
      }
      try {
        ((payload['extra'] as Map)['attempts'] as List).add(2);
      } on UnsupportedError {
        rejected.add('extra');
      }
    };

    ErrorReporter.instance.report(
      message: 'nested-payload-probe',
      level: 'warning',
      section: 'ObserverTest.nested',
      tags: tags,
      extra: extra,
    );

    expect(rejected, ['tags', 'extra'], reason: 'the snapshot is read-only all the way down');
    expect(tags, {'category': 'session'});
    expect(extra, {
      'attempts': [1],
    });
    expect(sent, hasLength(1));
    expect((sent.single['tags'] as Map)['category'], 'session', reason: 'the report that goes out is untouched');
    expect((sent.single['extra'] as Map)['attempts'], [1]);
  });

  test('a throwing observer does not cancel the report it was shown', () {
    final sent = <String>[];
    ErrorReporter.sendOverride = (payload) => sent.add(payload['message'] as String);
    ErrorReporter.observer = (_, _) => throw StateError('observer is broken');

    ErrorReporter.instance.report(
      message: 'throwing-observer-probe',
      level: 'warning',
      section: 'ObserverTest.throwing',
    );

    expect(sent, ['throwing-observer-probe'], reason: 'the report the observer threw on still goes out');

    final sections = <String>[];
    ErrorReporter.observer = (section, _) => sections.add(section);
    ErrorReporter.instance.report(
      message: 'after-throwing-observer-probe',
      level: 'warning',
      section: 'ObserverTest.after',
    );

    expect(sections, ['ObserverTest.after']);
    expect(sent, ['throwing-observer-probe', 'after-throwing-observer-probe']);
  });
}
