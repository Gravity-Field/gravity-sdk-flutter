import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/outbox/backoff.dart';

void main() {
  test('schedule is 5s, 15s, 45s, 2m, 5m, 15m', () {
    expect(Backoff.schedule, const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ]);
  });

  test(
    'random 0.5 yields the base delay; levels beyond the schedule cap at 15m',
    () {
      expect(Backoff.delayFor(0, random: 0.5), const Duration(seconds: 5));
      expect(Backoff.delayFor(3, random: 0.5), const Duration(minutes: 2));
      expect(Backoff.delayFor(5, random: 0.5), const Duration(minutes: 15));
      expect(Backoff.delayFor(42, random: 0.5), const Duration(minutes: 15));
    },
  );

  test('jitter stays within ±20%', () {
    expect(Backoff.delayFor(0, random: 0.0), const Duration(seconds: 4));
    final upper = Backoff.delayFor(0, random: 0.999999);
    expect(upper, greaterThan(const Duration(seconds: 5)));
    expect(upper, lessThanOrEqualTo(const Duration(seconds: 6)));
  });

  test('negative level is treated as 0', () {
    expect(Backoff.delayFor(-3, random: 0.5), const Duration(seconds: 5));
  });
}
