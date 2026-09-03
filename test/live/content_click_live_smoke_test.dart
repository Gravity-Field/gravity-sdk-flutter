import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live smoke check for [ContentClickEngagement] against the real backend.
///
/// Skipped by default so the regular suite stays offline. Run it explicitly:
///
///     GRAVITY_LIVE=1 fvm flutter test test/live/content_click_live_smoke_test.dart
///
/// Credentials come from `GRAVITY_LIVE_API_KEY` / `GRAVITY_LIVE_SECTION`, or,
/// when those are unset, from the demo section in `example/lib/main.dart`.
/// `GRAVITY_LIVE_SELECTOR` picks the campaign (default `inline_widget_qa`).
/// The check: the SDK sends the `click` URL it got from /choose, and the
/// server answers 204 to that exact URL.
void main() {
  final env = Platform.environment;
  final selector = env['GRAVITY_LIVE_SELECTOR'] ?? 'inline_widget_qa';

  ({String apiKey, String section})? credentials() {
    final apiKey = env['GRAVITY_LIVE_API_KEY'];
    final section = env['GRAVITY_LIVE_SECTION'];
    if (apiKey != null && section != null) return (apiKey: apiKey, section: section);

    final example = File('example/lib/main.dart');
    if (!example.existsSync()) return null;
    final source = example.readAsStringSync();
    final key = RegExp(r"apiKey:\s*'([^']+)'").firstMatch(source)?.group(1);
    final sec = RegExp(r"section:\s*'([^']+)'").firstMatch(source)?.group(1);
    if (key == null || sec == null) return null;
    return (apiKey: key, section: sec);
  }

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'click-live',
      packageName: 'ai.gravityfield.clicklive',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'click-live-ua', id: 'click-live-device');
    ErrorReporter.disableNetworkForTests = true;
  });

  tearDownAll(() async {
    GravityRepo.triggerEventUrlsObserver = null;
    await SessionManager.instance.resetSession();
  });

  test('live: ContentClickEngagement sends the click URL and the server accepts it', () async {
    if (env['GRAVITY_LIVE'] != '1') {
      markTestSkipped('Set GRAVITY_LIVE=1 to hit the real backend.');
      return;
    }
    final creds = credentials();
    if (creds == null) {
      markTestSkipped('Set GRAVITY_LIVE_API_KEY and GRAVITY_LIVE_SECTION (example/lib/main.dart not found).');
      return;
    }
    await GravitySDK.instance.initialize(apiKey: creds.apiKey, section: creds.section);

    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: selector,
      pageContext: const PageContext(type: ContextType.other, data: [], location: '/click-live'),
    );
    final campaigns = response.data.data;
    expect(campaigns, isNotEmpty, reason: 'No campaign for selector "$selector" in section ${creds.section}.');
    final campaign = campaigns.first;
    final content = campaign.payload.first.contents.first;

    final clickEvent = content.events?.where((e) => e.rawType == 'click').toList() ?? const [];
    expect(clickEvent, hasLength(1), reason: 'Server response carries no events[type=click] for "$selector".');

    final sent = <String>[];
    GravityRepo.triggerEventUrlsObserver = sent.addAll;
    GravitySDK.instance.sendContentEngagement(ContentClickEngagement(content, campaign));
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(sent, hasLength(1));
    expect(sent.single, contains('type=WCLICK'));
    expect(sent.single, clickEvent.single.urls.single);
    // ignore: avoid_print
    print('click URL sent by SDK: ${sent.single}');

    // The SDK swallows the tracking status on purpose; confirm acceptance of
    // the very same URL with a plain GET.
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(sent.single));
      request.headers.set('Authorization', 'Bearer ${creds.apiKey}');
      final status = (await request.close()).statusCode;
      // ignore: avoid_print
      print('server answered $status');
      expect(status, HttpStatus.noContent);
    } finally {
      client.close(force: true);
    }
  });
}
