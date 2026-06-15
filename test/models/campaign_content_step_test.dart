import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';

// Minimal valid content JSON. `variables: {}` parses because all Variables fields
// are optional; `products`/`events` keys are omitted (the generated deserializer
// passes them as null). Only the fields relevant to `step` parsing are included.
Map<String, dynamic> _content({int? step}) => {
      'contentId': 'c1',
      'deliveryMethod': 'inline',
      'contentType': 'native',
      'variables': <String, dynamic>{},
      if (step != null) 'step': step,
    };

void main() {
  group('CampaignContent.step', () {
    test('parses step when present', () {
      final content = CampaignContent.fromJson(_content(step: 1));
      expect(content.step, 1);
    });

    test('step is null when the key is absent', () {
      final content = CampaignContent.fromJson(_content());
      expect(content.step, isNull);
    });

    test('parses step 0 as a valid value', () {
      final content = CampaignContent.fromJson(_content(step: 0));
      expect(content.step, 0);
    });
  });
}
