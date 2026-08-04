import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/forms/condition_evaluator.dart';
import 'package:gravity_sdk/src/models/internal/condition.dart';

void main() {
  final vectors = jsonDecode(File('test/fixtures/condition_vectors.json').readAsStringSync()) as List;
  for (final v in vectors.cast<Map<String, dynamic>>()) {
    test('vector: ${v['name']}', () {
      final condition = Condition.tryParse(v['condition']);
      expect(condition, isNotNull, reason: 'vector condition must be structurally valid');
      final state = (v['state'] as Map<String, dynamic>).map((k, val) => MapEntry(k, val as Object?));
      expect(evaluateCondition(condition!, state), v['expected']);
    });
  }
}
