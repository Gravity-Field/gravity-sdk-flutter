/// Parsed content together with the raw server response it came from.
class GravityDataResponse<T> {
  /// Parsed response.
  final T data;

  /// Raw `/choose` response body. Exception: when the user identity changes
  /// or `GravitySDK.initialize` is called again while
  /// `getContent*WithDetails` is loading, the SDK returns a synthesized empty
  /// response and this is `{'user': {}, 'data': []}`.
  final Map<String, dynamic> json;

  /// Delay in milliseconds of the campaign chosen by
  /// `GravitySDK.trackViewNoShow` or `GravitySDK.triggerEventNoShow`.
  ///
  /// The SDK returns the response right after content loads; the app is
  /// responsible for waiting this delay before showing the content itself.
  /// `0` means no extra wait. Negative values are clamped to `0`.
  /// Always `0` for `getContent*WithDetails`, which have no campaign delay.
  final int delayTime;

  const GravityDataResponse({
    required this.data,
    required this.json,
    int delayTime = 0,
  }) : delayTime = delayTime < 0 ? 0 : delayTime;

  @override
  String toString() =>
      'GravityDataResponse<$T>(data: $data, json: $json, delayTime: $delayTime)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GravityDataResponse<T> &&
        other.data == data &&
        other.delayTime == delayTime &&
        _mapsEqual(other.json, json);
  }

  @override
  int get hashCode => Object.hash(
    data,
    Object.hashAllUnordered(
      json.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    delayTime,
  );

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
