import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _handleKey = ValueKey('gravityDragHandle');

// Inline map literals infer Map<dynamic, dynamic> for nested empty maps,
// which the generated parsers reject; the json round-trip mirrors what
// Dio's jsonDecode produces in production.
Campaign _campaign({
  Map<String, dynamic>? dragHandle,
  int textElements = 1,
}) => Campaign.fromJson(
  jsonDecode(
        jsonEncode({
          'selector': 'drag-handle-test',
          'payload': [
            {
              'campaignId': 'campaign-1',
              'experienceId': 'experience-1',
              'variationId': 'variation-1',
              'decisionId': 'decision-1',
              'contents': [
                {
                  'contentId': 'sheet-1',
                  'deliveryMethod': 'bottom_sheet',
                  'contentType': 'native',
                  'variables': {
                    'frameUI': {
                      'container': {
                        'style': {
                          'backgroundColor': '#ffffffff',
                          'cornerRadius': 12,
                          'padding': {
                            'left': 16,
                            'right': 16,
                            'top': 16,
                            'bottom': 16,
                          },
                        },
                      },
                      if (dragHandle != null) 'dragHandle': dragHandle,
                    },
                    'elements': [
                      for (var i = 0; i < textElements; i++)
                        {
                          'type': 'text',
                          'text': 'Контент $i',
                          'style': {'fontSize': 24},
                        },
                    ],
                  },
                },
              ],
            },
          ],
        }),
      )
      as Map<String, dynamic>,
);

CampaignContent _content(Campaign campaign) =>
    campaign.payload.first.contents.first;

Future<void> _pumpSheet(WidgetTester tester, Campaign campaign) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BottomSheetContent(
          content: _content(campaign),
          campaign: campaign,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('renders the configured handle above the content', (
    tester,
  ) async {
    final campaign = _campaign(
      dragHandle: {
        'style': {
          'visible': true,
          'backgroundColor': '#181d27ff',
          'size': {'width': 48, 'height': 6},
        },
      },
    );

    await _pumpSheet(tester, campaign);

    final handle = tester.widget<Container>(find.byKey(_handleKey));
    final decoration = handle.decoration! as BoxDecoration;
    expect(tester.getSize(find.byKey(_handleKey)), const Size(48, 6));
    expect(decoration.color, const Color(0xFF181D27));
    expect(decoration.borderRadius, BorderRadius.circular(3));
    expect(
      tester.getBottomLeft(find.byKey(_handleKey)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Контент 0')).dy),
      reason: 'The handle sits above the sheet content',
    );
    expect(
      tester.getCenter(find.byKey(_handleKey)).dx,
      tester.getSize(find.byType(BottomSheetContent)).width / 2,
      reason: 'The handle is horizontally centered',
    );
  });

  testWidgets('shows no handle without a dragHandle', (tester) async {
    await _pumpSheet(tester, _campaign());

    expect(find.byKey(_handleKey), findsNothing);
    expect(find.text('Контент 0'), findsOneWidget);
  });

  testWidgets('shows no handle when visible is false', (tester) async {
    final campaign = _campaign(
      dragHandle: {
        'style': {'visible': false},
      },
    );

    await _pumpSheet(tester, campaign);

    expect(find.byKey(_handleKey), findsNothing);
  });

  testWidgets('tall content stays scrollable under the handle', (
    tester,
  ) async {
    final campaign = _campaign(
      dragHandle: {
        'style': {'visible': true},
      },
      textElements: 60,
    );

    await _pumpSheet(tester, campaign);

    expect(
      tester.takeException(),
      isNull,
      reason: 'Unbounded content must not overflow the handle column',
    );
    final viewportHeight = tester.getSize(find.byType(Scaffold)).height;
    expect(
      tester.getTopLeft(find.text('Контент 59')).dy,
      greaterThan(viewportHeight),
      reason: 'The tail starts below the fold',
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -10000),
    );
    await tester.pump();

    expect(
      tester.getBottomLeft(find.text('Контент 59')).dy,
      lessThanOrEqualTo(viewportHeight),
      reason: 'The tail is reachable by scrolling under the pinned handle',
    );
    expect(tester.takeException(), isNull);
  });
}
