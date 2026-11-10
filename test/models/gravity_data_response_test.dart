import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

void main() {
  group('GravityDataResponse', () {
    test('delayTime defaults to 0', () {
      const response = GravityDataResponse<int>(data: 1, json: {'a': 1});
      expect(response.delayTime, 0);
    });

    test('negative delay is normalized by the const constructor', () {
      const response = GravityDataResponse<int>(
        data: 1,
        json: {},
        delayTime: -1,
      );
      expect(response.delayTime, 0);
    });

    test('equality and hashCode include delayTime', () {
      final a = GravityDataResponse<int>(
        data: 1,
        json: {'a': 1},
        delayTime: 1500,
      );
      final b = GravityDataResponse<int>(
        data: 1,
        json: {'a': 1},
        delayTime: 1500,
      );
      final c = GravityDataResponse<int>(data: 1, json: a.json);
      expect(identical(a, b), isFalse);
      expect(identical(a.json, b.json), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.hashCode, isNot(c.hashCode));
      expect(a.toString(), contains('delayTime: 1500'));
    });
  });
}
