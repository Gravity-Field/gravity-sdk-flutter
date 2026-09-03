import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live smoke check for the raw `variables` object against the real backend.
///
/// Skipped by default so the regular suite stays offline. Run it explicitly:
///
///     GRAVITY_LIVE=1 fvm flutter test test/live/raw_variables_live_smoke_test.dart
///
/// Credentials come from `GRAVITY_LIVE_API_KEY` / `GRAVITY_LIVE_SECTION`, or,
/// when those are unset, from the demo section in `example/lib/main.dart`
/// (single source, nothing is duplicated here). The demo `inline_banner`
/// campaign only carries typed keys, so by default this proves that
/// `rawVariables` is the complete server object; set `GRAVITY_LIVE_SELECTOR`
/// and `GRAVITY_LIVE_KEY` to assert a campaign-specific key on another stand.
void main() {
  final env = Platform.environment;
  final selector = env['GRAVITY_LIVE_SELECTOR'] ?? 'inline_banner';
  final expectedKey = env['GRAVITY_LIVE_KEY'];

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
      appName: 'raw-vars-live',
      packageName: 'ai.gravityfield.rawvarslive',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'raw-vars-live-ua', id: 'raw-vars-live-device');
    ErrorReporter.disableNetworkForTests = true;
  });

  tearDownAll(() async {
    await SessionManager.instance.resetSession();
  });

  test('live /choose: rawVariables equals the variables object on the wire', () async {
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
      pageContext: const PageContext(type: ContextType.other, data: [], location: '/raw-vars-live'),
    );

    final campaigns = response.data.data;
    expect(
      campaigns,
      isNotEmpty,
      reason: 'No campaign for selector "$selector" in section ${creds.section}. '
          'Check that the campaign is active in the dashboard.',
    );

    final content = campaigns.first.payload.first.contents.first;
    final wire = (((response.json['data'] as List).first as Map)['payload'] as List).first as Map;
    final wireVariables = ((wire['contents'] as List).first as Map)['variables'] as Map<String, dynamic>;

    // ignore: avoid_print
    print('rawVariables keys for "$selector": ${content.rawVariables.keys.toList()}');

    expect(const DeepCollectionEquality().equals(content.rawVariables, wireVariables), isTrue);
    expect(content.rawVariables.keys, containsAll(wireVariables.keys));
    expect(() => content.rawVariables['x'] = 1, throwsUnsupportedError);

    if (expectedKey != null) {
      expect(
        content.variables[expectedKey],
        isNotNull,
        reason: 'Campaign "$selector" was expected to carry variables["$expectedKey"].',
      );
      // ignore: avoid_print
      print('variables["$expectedKey"] = ${content.variables[expectedKey]}');
    }
  });
}
