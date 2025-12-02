class GravityDataResponse<T> {
  final T data;
  final Map<String, dynamic> json;

  const GravityDataResponse({required this.data, required this.json});

  @override
  String toString() => 'GravityDataResponse<$T>(data: $data, json: $json)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GravityDataResponse<T> && other.data == data && _mapsEqual(other.json, json);
  }

  @override
  int get hashCode => Object.hash(data, json.hashCode);

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
