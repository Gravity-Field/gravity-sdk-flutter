import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/logger.dart';

Campaign _loadCampaign() {
  final json =
      jsonDecode(File('test/fixtures/in_app_survey_payload.json').readAsStringSync())
          as Map<String, dynamic>;
  return ContentResponse.fromJson(json).data.first;
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
    GravitySDK.instance.apiKey = 'test-key';
    GravitySDK.instance.section = 'test-section';
  });

  setUp(() => GravityRepo.triggerEventUrlsObserver = null);
  tearDown(() => GravityRepo.triggerEventUrlsObserver = null);

  testWidgets('ContentClickEngagement sends the WCLICK url from events[type=click]', (tester) async {
    final campaign = _loadCampaign();
    final content = campaign.payload.first.contents.first;
    final sent = <String>[];
    GravityRepo.triggerEventUrlsObserver = sent.addAll;

    // runAsync: the fire-and-forget GET must finish against flutter_test's
    // stub HttpClient instead of leaving a pending timer.
    await tester.runAsync(() async {
      GravitySDK.instance.sendContentEngagement(
        ContentClickEngagement(content, campaign),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(sent, hasLength(1));
    expect(sent.single, contains('type=WCLICK'));
    expect(sent.single, contains('contentId=${content.contentId}'));
  });

  testWidgets('no events[type=click] is a silent no-op', (tester) async {
    final campaign = _loadCampaign();
    final content = CampaignContent(
      contentId: 'no-click-content',
      templateSystemName: null,
      deliveryMethod: DeliveryMethod.inline,
      contentType: 'banner',
      variables: campaign.payload.first.contents.first.variables,
      products: null,
      events: campaign.payload.first.contents.first.events
          ?.where((e) => e.rawType != 'click')
          .toList(),
    );
    final sent = <String>[];
    GravityRepo.triggerEventUrlsObserver = sent.addAll;

    await tester.runAsync(() async {
      GravitySDK.instance.sendContentEngagement(
        ContentClickEngagement(content, campaign),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(sent, isEmpty);
  });

  test('rawType keeps the wire type while type parses as unknown', () {
    final content = _loadCampaign().payload.first.contents.first;
    final click = content.events!.firstWhere((e) => e.rawType == 'click');
    expect(click.type, Action.unknown);
    expect(content.events!.where((e) => e.type == Action.unknown).length,
        greaterThanOrEqualTo(1));
  });

  testWidgets('events == null is a silent no-op', (tester) async {
    final campaign = _loadCampaign();
    final original = campaign.payload.first.contents.first;
    final content = CampaignContent(
      contentId: original.contentId,
      templateSystemName: original.templateSystemName,
      deliveryMethod: original.deliveryMethod,
      contentType: original.contentType,
      variables: original.variables,
      products: null,
      events: null,
    );
    final sent = <String>[];
    GravityRepo.triggerEventUrlsObserver = sent.addAll;

    await tester.runAsync(() async {
      GravitySDK.instance.sendContentEngagement(
        ContentClickEngagement(content, campaign),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(sent, isEmpty);
  });

  testWidgets('an unknown onImpression action never fires the click url', (tester) async {
    final campaign = _loadCampaign();
    final original = campaign.payload.first.contents.first;
    final content = CampaignContent(
      contentId: original.contentId,
      templateSystemName: original.templateSystemName,
      deliveryMethod: original.deliveryMethod,
      contentType: original.contentType,
      variables: Variables(onImpression: const ContentAction(action: Action.unknown)),
      products: null,
      events: original.events,
    );
    final sent = <String>[];
    GravityRepo.triggerEventUrlsObserver = sent.addAll;

    await tester.runAsync(() async {
      GravitySDK.instance.sendContentEngagement(
        ContentImpressionEngagement(content, campaign),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(sent, isEmpty);
  });
}
