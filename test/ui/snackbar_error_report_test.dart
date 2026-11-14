import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'snackbar_events_test.dart' show campaign;

void main() {
  testWidgets('snackbar show omits HTTP exception body from error report', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => SessionManager.instance.restoreUserId('test-uid'),
    );
    final reports = <Map<String, dynamic>>[];
    ErrorReporter.disableNetworkForTests = true;
    ErrorReporter.sendOverride = reports.add;
    addTearDown(() => ErrorReporter.sendOverride = null);
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final request = RequestOptions(
      path: 'https://example.test/choose?token=secret',
    );
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 500),
      message: 'private-response-body',
      type: DioExceptionType.badResponse,
    );
    var released = 0;
    final data = campaign();
    SnackBarContent.show(
      context: host,
      snackBarContent: SnackBarContent.getSnackBar(
        template: TemplateSystemName.snackbar1,
        content: data.payload.first.contents.first,
        campaign: data,
      ),
      durationSeconds: 4,
      // The validity callback runs inside show's catch boundary; an HTTP
      // exception must receive the same treatment as other SDK boundaries.
      impression: ModalImpression(
        onVisible: () async {},
        isValid: () => throw error,
        onUnshownClose: () => released++,
      ),
    );
    await tester.pump();
    expect(released, 1);
    expect(reports, hasLength(1));
    expect(
      reports.single['message'],
      'DioException [badResponse] GET https://example.test/choose -> 500',
    );
    expect(reports.toString(), isNot(contains('private-response-body')));
    expect(reports.toString(), isNot(contains('token=secret')));
    expect(tester.takeException(), isNull);
  });
}
