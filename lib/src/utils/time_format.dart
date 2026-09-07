/// RFC 3339 timestamp in UTC with millisecond precision,
/// e.g. `2026-08-28T11:00:00.123Z`. Used for `eventTime` on the wire.
String formatEventTime(DateTime time) {
  final t = time.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final year = t.year.toString().padLeft(4, '0');
  final ms = t.millisecond.toString().padLeft(3, '0');
  return '$year-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${ms}Z';
}
