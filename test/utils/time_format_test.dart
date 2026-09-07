import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/time_format.dart';

void main() {
  group('formatEventTime', () {
    test('formats UTC with millisecond precision and Z suffix', () {
      final t = DateTime.utc(2026, 8, 28, 11, 0, 0, 123);
      expect(formatEventTime(t), '2026-08-28T11:00:00.123Z');
    });

    test('converts local time to UTC', () {
      // A local DateTime for a fixed instant: the expected string is the same
      // in every timezone, so the conversion is really checked.
      final local = DateTime.fromMillisecondsSinceEpoch(1788000000123);
      expect(local.isUtc, isFalse);
      expect(formatEventTime(local), '2026-08-29T10:40:00.123Z');
    });

    test('pads single-digit fields and truncates microseconds', () {
      final t = DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 999);
      expect(formatEventTime(t), '2026-01-02T03:04:05.006Z');
    });
  });

  group('Clock', () {
    test('defaults to DateTime.now and can be overridden', () {
      final before = DateTime.now();
      final now = Clock.now();
      expect(now.isBefore(before), isFalse);

      final fixed = DateTime.utc(2030, 1, 1);
      Clock.now = () => fixed;
      addTearDown(() => Clock.now = DateTime.now);
      expect(Clock.now(), fixed);
    });
  });
}
