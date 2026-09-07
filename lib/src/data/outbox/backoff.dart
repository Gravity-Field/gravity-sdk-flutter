/// Pause schedule between outbox drain attempts.
class Backoff {
  Backoff._();

  static const List<Duration> schedule = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  /// Delay for the given 0-based [level], capped at the last schedule entry,
  /// with ±20% jitter driven by [random] in `[0, 1)`.
  static Duration delayFor(int level, {required double random}) {
    final base = schedule[level.clamp(0, schedule.length - 1)];
    final factor = 0.8 + 0.4 * random;
    return Duration(microseconds: (base.inMicroseconds * factor).round());
  }
}
