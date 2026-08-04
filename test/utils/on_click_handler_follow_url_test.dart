import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/tracking_event.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/models/internal/campaign_variation.dart';
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/variables.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';

// events: null — иначе матч tracking-событий дёргает реальные URL и оставляет
// висящие Dio-таймеры в testWidgets.
final _content = CampaignContent(
  contentId: 'follow-url-content',
  templateSystemName: null,
  deliveryMethod: DeliveryMethod.modal,
  contentType: 'native',
  variables: Variables(elements: const []),
  products: null,
  events: null,
);

final _campaign = Campaign(
  selector: null,
  payload: [
    CampaignVariation(
      campaignId: 'campaign-1',
      experienceId: 'experience-1',
      variationId: 'variation-1',
      decisionId: 'decision-1',
      contents: [_content],
    ),
  ],
);

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
  });

  setUp(() {
    GravitySDK.instance.gravityEventCallback = null;
  });

  tearDown(() {
    GravitySDK.instance.gravityEventCallback = null;
  });

  Future<FollowUrlEvent> clickFollowUrl(
    WidgetTester tester,
    Map<String, dynamic> onClickJson,
  ) async {
    final context = await _pumpContext(tester);
    final callbacks = <TrackingEvent>[];
    GravitySDK.instance.gravityEventCallback = callbacks.add;

    OnClickHandler(
      content: _content,
      campaign: _campaign,
    ).handeOnClick(OnClick.fromJson(onClickJson), context);
    await tester.pump();

    return callbacks.whereType<FollowUrlEvent>().single;
  }

  testWidgets('passes webview type through to the host', (tester) async {
    final event = await clickFollowUrl(tester, {
      'action': 'follow_url',
      'url': 'https://example.com/page',
      'type': 'webview',
    });

    expect(event.url, 'https://example.com/page');
    expect(event.type, FollowUrlType.webview);
  });

  testWidgets('passes browser type through to the host', (tester) async {
    final event = await clickFollowUrl(tester, {
      'action': 'follow_url',
      'url': 'https://example.com/page',
      'type': 'browser',
    });

    expect(event.type, FollowUrlType.browser);
  });

  testWidgets('legacy campaign without type reaches the host as browser', (
    tester,
  ) async {
    final event = await clickFollowUrl(tester, {
      'action': 'follow_url',
      'url': 'https://example.com/page',
    });

    expect(event.type, FollowUrlType.browser);
  });
}
