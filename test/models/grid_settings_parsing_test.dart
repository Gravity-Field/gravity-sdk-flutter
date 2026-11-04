import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:gravity_sdk/src/utils/parse_utils.dart';

void main() {
  for (final raw in [12, 12.0, '12px', '12']) {
    test('dimension $raw (${raw.runtimeType}) parses as twelve', () {
      expect(ParseUtils.parseDimension(raw), 12);
      final settings = GridSettings.fromJson({
        'columns': raw,
        'horizontalSpacing': raw,
        'verticalSpacing': raw,
      });
      expect(settings.columnsCount, 12);
      expect(settings.horizontalSpacingValue, 12);
      expect(settings.verticalSpacingValue, 12);
    });
  }

  for (final raw in <double?>[
    null,
    0,
    -1,
    13,
    10000,
    double.nan,
    double.infinity,
  ]) {
    test('invalid column count $raw falls back to two', () {
      expect(GridSettings(columns: raw).columnsCount, 2);
    });
  }

  test('valid counts retain integer conversion and default spacing', () {
    expect(GridSettings(columns: 3.9).columnsCount, 3);
    expect(GridSettings(columns: 1).columnsCount, 1);
    expect(GridSettings().horizontalSpacingValue, 8);
    expect(GridSettings().verticalSpacingValue, 8);
    expect(ParseUtils.parseDimension('invalid'), isNull);
  });

  for (final (name, raw, expected) in <(String, Object?, double)>[
    ('missing', null, 8),
    ('negative number', -4, 8),
    ('negative px string', '-4px', 8),
    ('negative numeric string', '-0.5', 8),
    ('NaN', 'NaN', 8),
    ('infinity', 'Infinity', 8),
    ('negative infinity', '-Infinity', 8),
    ('zero', 0, 0),
    ('positive', 2.5, 2.5),
  ]) {
    test('grid spacing $name resolves safely on both axes', () {
      final settings = GridSettings.fromJson({
        'horizontalSpacing': raw,
        'verticalSpacing': raw,
      });
      expect(settings.horizontalSpacingValue, expected);
      expect(settings.verticalSpacingValue, expected);
    });
  }
}
