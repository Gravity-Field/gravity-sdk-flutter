import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

void main() {
  test('unit suites never enable the live error-report transport', () {
    expect(ErrorReporter.disableNetworkForTests, isTrue);
  });

  test('unit HTTP clients reject remote hosts before transport', () async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    await expectLater(
      () => client.getUrl(Uri.parse('https://blocked.invalid/fixture')),
      throwsA(isA<StateError>()),
    );
  });
}
