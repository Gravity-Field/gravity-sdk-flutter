import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

Map<String, dynamic> nativeJsonContent() => {
      'contentId': 'c1',
      'deliveryMethod': 'json',
      'contentType': 'native',
    };

void main() {
  test('content without variables parses with empty variables', () {
    final content = CampaignContent.fromJson(nativeJsonContent());

    expect(content.deliveryMethod, DeliveryMethod.json);
    expect(content.rawVariables, isEmpty);
    expect(content.variables.frameUI, isNull);
    expect(content.variables.elements, isNull);
    expect(content.variables.index, 0);
  });

  test('content with null variables parses with empty variables', () {
    final content = CampaignContent.fromJson({...nativeJsonContent(), 'variables': null});

    expect(content.rawVariables, isEmpty);
    expect(content.variables.onLoad, isNull);
  });
}
