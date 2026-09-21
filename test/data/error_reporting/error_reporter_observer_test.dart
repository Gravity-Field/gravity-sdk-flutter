import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

/// The observer is a test seam that sits on the path of every report. It may
/// neither see a payload it could rewrite on its way out nor, by throwing,
/// decide that the report is not worth sending.
void main() {
  tearDown(() => ErrorReporter.observer = null);

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

  test('a throwing observer does not break reporting', () {
    ErrorReporter.observer = (_, _) => throw StateError('observer is broken');
    ErrorReporter.instance.report(
      message: 'throwing-observer-probe',
      level: 'warning',
      section: 'ObserverTest.throwing',
    );

    final sections = <String>[];
    ErrorReporter.observer = (section, _) => sections.add(section);
    ErrorReporter.instance.report(
      message: 'after-throwing-observer-probe',
      level: 'warning',
      section: 'ObserverTest.after',
    );

    expect(sections, ['ObserverTest.after']);
  });
}
