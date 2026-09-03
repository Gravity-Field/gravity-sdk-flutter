import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

CampaignContent contentWith(Map<String, dynamic> variables) => CampaignContent.fromJson({
  'contentId': 'c1',
  'deliveryMethod': 'inline',
  'contentType': 'html',
  'variables': variables,
});

void main() {
  test('arbitrary variables keys are exposed via raw', () {
    final content = contentWith({
      'title': 'typed still works',
      'inline_banner': {'variant': 'B', 'discount': 15},
      'flag': true,
    });

    expect(content.variables.title, 'typed still works');
    expect(content.rawVariables['flag'], true);
    expect(content.variables['inline_banner'], isA<Map<String, dynamic>>());
    expect(
      content.variables.valueOf<Map<String, dynamic>>('inline_banner')?['variant'],
      'B',
    );
    expect(content.variables.valueOf<String>('flag'), isNull);
    expect(
      () => content.rawVariables['x'] = 1,
      throwsUnsupportedError,
    );
  });

  test('manually constructed Variables has empty raw', () {
    expect(Variables(title: 't').raw, isEmpty);
    expect(Variables(title: 't')['anything'], isNull);
    expect(Variables(title: 't').valueOf<String>('anything'), isNull);
  });

  test('an empty variables object yields an empty raw and null lookups', () {
    final content = contentWith(<String, dynamic>{});

    expect(content.rawVariables, isEmpty);
    expect(content.variables['x'], isNull);
    expect(content.variables.valueOf<int>('x'), isNull);
    expect(content.variables.valueOf<Map<String, dynamic>>('x'), isNull);
    // Typed accessors keep their documented defaults on an empty object.
    expect(content.variables.title, isNull);
    expect(content.variables.elements, isNull);
    expect(content.variables.frameUI, isNull);
  });

  test('a null value stored under a key is not confused with a missing key', () {
    final content = contentWith({'maybe': null});

    expect(content.rawVariables.containsKey('maybe'), isTrue);
    expect(content.variables['maybe'], isNull);
    expect(content.variables.valueOf<String>('maybe'), isNull);
    expect(content.rawVariables.containsKey('absent'), isFalse);
  });

  test('raw is the whole variables object, not the untyped remainder', () {
    final variables = <String, dynamic>{
      'title': 'only typed keys here',
      'index': 3,
    };
    final content = contentWith(variables);

    expect(content.rawVariables.keys, containsAll(<String>['title', 'index']));
    expect(content.rawVariables, hasLength(2));
    expect(
      const DeepCollectionEquality().equals(content.rawVariables, variables),
      isTrue,
    );
    // The typed view keeps working alongside the raw one.
    expect(content.variables.title, 'only typed keys here');
    expect(content.variables.index, 3);
  });

  test('raw is detached from the source map that was parsed', () {
    final variables = <String, dynamic>{'kept': 1};
    final content = contentWith(variables);

    variables['added-later'] = 2;

    expect(content.rawVariables.containsKey('added-later'), isFalse);
    expect(content.rawVariables['kept'], 1);
  });
}
