import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/utils/step_resolver.dart';

Map<String, dynamic> _content(String id, {int? step, String method = 'inline'}) => {
      'contentId': id,
      'deliveryMethod': method,
      'contentType': 'native',
      'variables': <String, dynamic>{},
      if (step != null) 'step': step,
    };

Campaign _campaign(List<Map<String, dynamic>> contents) => Campaign.fromJson({
      'selector': 's',
      'payload': [
        {
          'campaignId': 'c',
          'experienceId': 'e',
          'variationId': 'v',
          'decisionId': 'd',
          'contents': contents,
        },
      ],
    });

void main() {
  group('resolveStepContent', () {
    test('finds the content with the matching step', () {
      final campaign = _campaign([
        _content('root'),
        _content('s1', step: 1, method: 'bottom_sheet'),
      ]);
      expect(resolveStepContent(campaign, 1)?.contentId, 's1');
    });

    test('returns null when no content has the step', () {
      final campaign = _campaign([_content('root')]);
      expect(resolveStepContent(campaign, 2), isNull);
    });

    test('returns null for a null step', () {
      final campaign = _campaign([_content('root')]);
      expect(resolveStepContent(campaign, null), isNull);
    });

    test('finds a step located in a later variation', () {
      final campaign = Campaign.fromJson({
        'selector': 's',
        'payload': [
          {
            'campaignId': 'c', 'experienceId': 'e', 'variationId': 'v1', 'decisionId': 'd1',
            'contents': [_content('root')],
          },
          {
            'campaignId': 'c', 'experienceId': 'e', 'variationId': 'v2', 'decisionId': 'd2',
            'contents': [_content('s2', step: 2, method: 'modal')],
          },
        ],
      });
      expect(resolveStepContent(campaign, 2)?.contentId, 's2');
    });
  });

  group('resolveRootContent', () {
    test('returns the content without a step', () {
      final campaign = _campaign([
        _content('root'),
        _content('s1', step: 1, method: 'bottom_sheet'),
      ]);
      expect(resolveRootContent(campaign.payload.first.contents)?.contentId, 'root');
    });

    test('skips step contents even when they come first', () {
      final campaign = _campaign([
        _content('s1', step: 1, method: 'bottom_sheet'),
        _content('root'),
      ]);
      expect(resolveRootContent(campaign.payload.first.contents)?.contentId, 'root');
    });

    test('returns null when no content is marked root', () {
      final campaign = _campaign([
        _content('s1', step: 1, method: 'bottom_sheet'),
      ]);
      expect(resolveRootContent(campaign.payload.first.contents), isNull);
    });

    test('returns null for empty list', () {
      expect(resolveRootContent(const []), isNull);
    });
  });
}
