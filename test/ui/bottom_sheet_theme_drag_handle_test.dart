import 'dart:convert';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// The host app may enable Material's own drag handle globally through
/// `bottomSheetTheme.showDragHandle`. These tests pin the contract for how the
/// SDK-rendered sheet (opened through the real `showModalBottomSheet` call in
/// GravitySDK) coexists with that theme:
///
/// * backend sends `frameUI.dragHandle` → the SDK handle wins, the theme handle
///   is suppressed (no double handle);
/// * backend sends nothing → the theme handle keeps working as before.
const _sdkHandleKey = ValueKey('gravityDragHandle');

Campaign _campaign({Map<String, dynamic>? dragHandle}) => Campaign.fromJson(
  jsonDecode(
        jsonEncode({
          'selector': 'theme-drag-handle-test',
          'payload': [
            {
              'campaignId': 'campaign-1',
              'experienceId': 'experience-1',
              'variationId': 'variation-1',
              'decisionId': 'decision-1',
              'contents': [
                {
                  'contentId': 'root-inline',
                  'deliveryMethod': 'inline',
                  'contentType': 'native',
                  'variables': {
                    'frameUI': {
                      'container': {'style': {}},
                    },
                    'elements': [
                      {'type': 'text', 'text': 'Root'},
                    ],
                  },
                },
                {
                  'contentId': 'sheet-step-1',
                  'step': 1,
                  'deliveryMethod': 'bottom_sheet',
                  'contentType': 'native',
                  'variables': {
                    'frameUI': {
                      'container': {
                        'style': {'backgroundColor': '#ffffffff'},
                      },
                      if (dragHandle != null) 'dragHandle': dragHandle,
                    },
                    'elements': [
                      {
                        'type': 'text',
                        'text': 'Sheet body',
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

/// Opens the step-1 bottom sheet through GravitySDK.openStep, i.e. through the
/// production `showModalBottomSheet` call, inside a host app with [theme].
Future<void> _openSheetViaSdk(
  WidgetTester tester, {
  required Campaign campaign,
  required ThemeData theme,
}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            hostContext = context;
            return const Text('Host route');
          },
        ),
      ),
    ),
  );

  GravitySDK.instance.openStep(
    context: hostContext,
    onClick: OnClick(action: Action.openStep, step: 1),
    currentContent: campaign.payload.single.contents.first,
    campaign: campaign,
  );
  await tester.pumpAndSettle();

  expect(find.byType(BottomSheetContent), findsOneWidget);
  expect(find.text('Sheet body'), findsOneWidget);
}

ThemeData _themeWithHandle() => ThemeData(
  useMaterial3: true,
  bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
);

/// Distance from the top of Material's BottomSheet to the top of the SDK
/// content. Material reserves [kMinInteractiveDimension] above the builder
/// output when its own drag handle is shown, so this is a direct observation
/// of whether the theme handle was rendered.
double _contentOffsetFromSheetTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(BottomSheetContent)).dy -
    tester.getTopLeft(find.byType(BottomSheet)).dy;

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'backend dragHandle suppresses the theme handle — exactly one handle',
    (tester) async {
      await _openSheetViaSdk(
        tester,
        campaign: _campaign(
          dragHandle: {
            'style': {'visible': true},
          },
        ),
        theme: _themeWithHandle(),
      );

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(
        sheet.showDragHandle,
        isFalse,
        reason: 'An explicit false must override bottomSheetTheme.showDragHandle',
      );
      expect(find.byKey(_sdkHandleKey), findsOneWidget);
      expect(
        _contentOffsetFromSheetTop(tester),
        0,
        reason: 'No Material handle strip above the SDK content',
      );
    },
  );

  testWidgets(
    'without backend dragHandle the theme handle still applies',
    (tester) async {
      await _openSheetViaSdk(
        tester,
        campaign: _campaign(),
        theme: _themeWithHandle(),
      );

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(
        sheet.showDragHandle,
        isTrue,
        reason:
            'The modal route resolves bottomSheetTheme.showDragHandle when the SDK passes null',
      );
      expect(find.byKey(_sdkHandleKey), findsNothing);
      expect(
        _contentOffsetFromSheetTop(tester),
        kMinInteractiveDimension,
        reason: 'Material rendered its own handle strip from the theme',
      );
    },
  );

  testWidgets(
    'without backend dragHandle and a plain theme there is no handle at all',
    (tester) async {
      await _openSheetViaSdk(
        tester,
        campaign: _campaign(),
        theme: ThemeData(useMaterial3: true),
      );

      expect(find.byKey(_sdkHandleKey), findsNothing);
      expect(_contentOffsetFromSheetTop(tester), 0);
    },
  );
}
