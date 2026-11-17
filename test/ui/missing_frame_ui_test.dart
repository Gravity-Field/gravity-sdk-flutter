import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/ui/widgets/close_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sdk = GravitySDK.instance;
  final reports = <Map<String, dynamic>>[];
  // Tracking warnings (the fixtures carry no event URLs) are not failures.
  List<Map<String, dynamic>> errorReports() =>
      reports.where((r) => r['level'] == 'error').toList();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    ErrorReporter.disableNetworkForTests = true;
    ErrorReporter.sendOverride = reports.add;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    await sdk.initialize(apiKey: 'key', section: 'section');
    await SessionManager.instance.restoreUserId('test-uid');
  });
  tearDownAll(() {
    ErrorReporter.sendOverride = null;
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  // Opens [target] the way a backend step transition does and returns the
  // host context. [variables] null means the key is absent from the payload.
  Future<BuildContext> show(
    WidgetTester tester,
    String method,
    Map<String, dynamic>? variables,
  ) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    reports.clear();
    final target = CampaignContent.fromJson({
      'contentId': 'target',
      'deliveryMethod': method,
      'templateSystemName': 'snackbar-1',
      'contentType': 'native',
      'step': 1,
      'variables': ?variables,
    });
    final inline = CampaignContent.fromJson({
      'contentId': 'inline',
      'deliveryMethod': 'inline',
      'contentType': 'native',
      'variables': <String, dynamic>{},
    });
    final campaign = Campaign(
      selector: null,
      payload: [
        CampaignVariation(
          campaignId: 'c',
          experienceId: 'e',
          variationId: 'v',
          decisionId: 'd',
          contents: [inline, target],
        ),
      ],
    );
    await tester.runAsync(() async {
      sdk.openStep(
        context: host,
        onClick: OnClick(action: Action.openStep, step: 1),
        currentContent: inline,
        campaign: campaign,
      );
    });
    await tester.pumpAndSettle();
    return host;
  }

  final withElements = <String, dynamic>{
    'elements': [
      {'type': 'text', 'text': 'target', 'style': <String, dynamic>{}},
    ],
  };

  testWidgets('snackbar without frameUI is skipped', (tester) async {
    await show(tester, 'snackbar', withElements);

    expect(tester.takeException(), isNull);
    expect(find.text('target'), findsNothing);
    expect(errorReports(), isEmpty);
  });

  for (final method in ['modal', 'bottom_sheet', 'full_screen']) {
    testWidgets('$method without frameUI renders elements with defaults', (
      tester,
    ) async {
      final host = await show(tester, method, withElements);

      expect(tester.takeException(), isNull);
      expect(errorReports(), isEmpty);
      expect(find.text('target'), findsOneWidget);
      expect(find.byType(GravityCloseButtonWidget), findsNothing);

      Navigator.of(host, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expect(find.text('target'), findsNothing);
    });

    testWidgets('$method without variables opens and closes', (tester) async {
      final host = await show(tester, method, null);

      expect(tester.takeException(), isNull);
      expect(errorReports(), isEmpty);

      Navigator.of(host, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expect(find.text('host'), findsOneWidget);
    });
  }
}
