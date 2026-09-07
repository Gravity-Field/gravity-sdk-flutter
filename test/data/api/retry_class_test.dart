import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/retry_class.dart';

void main() {
  final options = RequestOptions(path: 'https://example.test/v2/event');

  DioException dio(DioExceptionType type, {int? status, Object? error}) =>
      DioException(
        requestOptions: options,
        type: type,
        error: error,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status),
      );

  group('classifyError', () {
    test('network-level failures are transient', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(classifyError(dio(type)), RetryClass.transient, reason: '$type');
      }
      expect(
        classifyError(const SocketException('down')),
        RetryClass.transient,
      );
      expect(
        classifyError(
          dio(DioExceptionType.unknown, error: const SocketException('down')),
        ),
        RetryClass.transient,
      );
    });

    test('408, 429 and 5xx are server failures', () {
      for (final status in [408, 429, 500, 502, 503, 504, 599]) {
        expect(
          classifyError(dio(DioExceptionType.badResponse, status: status)),
          RetryClass.server,
          reason: '$status',
        );
      }
    });

    test('other 4xx and non-network errors are permanent', () {
      for (final status in [400, 401, 403, 404, 422]) {
        expect(
          classifyError(dio(DioExceptionType.badResponse, status: status)),
          RetryClass.permanent,
          reason: '$status',
        );
      }
      expect(
        classifyError(dio(DioExceptionType.badResponse)),
        RetryClass.permanent,
      );
      expect(classifyError(dio(DioExceptionType.cancel)), RetryClass.permanent);
      expect(
        classifyError(dio(DioExceptionType.badCertificate)),
        RetryClass.permanent,
      );
      expect(
        classifyError(dio(DioExceptionType.unknown)),
        RetryClass.permanent,
      );
      expect(
        classifyError(const FormatException('bad json')),
        RetryClass.permanent,
      );
      expect(classifyError(StateError('x')), RetryClass.permanent);
    });
  });

  test('unknown wrapping an HttpException (connection severed mid-response) is transient', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/event'),
      type: DioExceptionType.unknown,
      error: const HttpException('Connection closed before full header was received'),
    );
    expect(classifyError(error), RetryClass.transient);
  });

  test('unknown wrapping a non-I/O error stays permanent', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/event'),
      type: DioExceptionType.unknown,
      error: const FormatException('bad json'),
    );
    expect(classifyError(error), RetryClass.permanent);
  });
}
