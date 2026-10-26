import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';

void main() {
  test(
    'parallel requests reserve once and stale responses stay rejected after ack',
    () {
      final gate = InAppPresentationGate();
      final a = gate.beginRequest('/a', 1);
      final b = gate.beginRequest('/a', 1);
      final reservation = gate.reserve('section/user', 'campaign', a)!;
      expect(gate.reserve('section/user', 'campaign', b), isNull);
      gate.acknowledged('section/user', 'campaign');
      expect(gate.reserve('section/user', 'campaign', b), isNull);
      expect(
        gate.reserve('section/user', 'campaign', gate.beginRequest('/a', 1)),
        isNotNull,
      );
      gate.cancel(reservation);
    },
  );
  test('unshown reservation releases; sections and users are isolated', () {
    final gate = InAppPresentationGate();
    final request = gate.beginRequest('/a', 1);
    final first = gate.reserve('section/a', 'campaign', request)!;
    expect(gate.reserve('section/b', 'campaign', request), isNotNull);
    expect(gate.reserve('other/a', 'campaign', request), isNotNull);
    gate.cancel(first);
    expect(gate.reserve('section/a', 'campaign', request), isNotNull);
  });
  test('screen and user generations invalidate old work', () {
    final gate = InAppPresentationGate();
    final old = gate.beginRequest('/a', 1);
    final reservation = gate.reserve('s/u', 'campaign', old)!;
    gate.beginRequest('/b', 1);
    expect(gate.isCurrent(reservation), isFalse);
    expect(gate.reserve('s/u', 'campaign', old), isNull);
    final beforeReset = gate.beginRequest('/b', 1);
    gate.beginRequest('/b', 2);
    expect(gate.reserve('s/u', 'campaign', beforeReset), isNull);
  });
  test('lost callback expires rather than suppressing a campaign forever', () {
    var now = DateTime(2026);
    final gate = InAppPresentationGate(now: () => now);
    final request = gate.beginRequest('/a', 1);
    gate.reserve('s/u', 'campaign', request);
    now = now.add(const Duration(seconds: 61));
    expect(
      gate.reserve('s/u', 'campaign', gate.beginRequest('/a', 1)),
      isNotNull,
    );
  });
}
