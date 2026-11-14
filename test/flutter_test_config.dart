import 'dart:async';
import 'dart:io';

import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

import 'support/loopback_http_overrides.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Payload tests use sendOverride. Inherited observer-only tests must not
  // contact the live reporting service either.
  ErrorReporter.disableNetworkForTests = true;
  HttpOverrides.global = LoopbackHttpOverrides();
  await testMain();
}
