import 'dart:async';
import 'dart:io';

import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Payload tests use sendOverride. Inherited observer-only tests must not
  // contact the live reporting service either.
  ErrorReporter.disableNetworkForTests = true;
  HttpOverrides.global = _LocalFixturesOnly();
  await testMain();
}

class _LocalFixturesOnly extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) {
      if (const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
        return 'DIRECT';
      }
      throw StateError('Unit tests allow only loopback HTTP fixtures');
    };
    return client;
  }
}
