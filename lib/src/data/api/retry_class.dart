import 'dart:io';

import 'package:dio/dio.dart';

/// How a failed request is treated by the transient retry and the outbox.
enum RetryClass {
  /// Network unavailable or unstable. Retry; attempt counters stay untouched.
  transient,

  /// The server saw the request but could not serve it (408/429/5xx).
  /// Retry; attempt counters grow.
  server,

  /// Retrying cannot help: other 4xx, parse errors, cancellations,
  /// non-network exceptions.
  permanent,
}

RetryClass classifyError(Object error) {
  if (error is SocketException) return RetryClass.transient;
  if (error is! DioException) return RetryClass.permanent;

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return RetryClass.transient;
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      if (status == null) return RetryClass.permanent;
      if (status == 408 || status == 429 || status >= 500) {
        return RetryClass.server;
      }
      return RetryClass.permanent;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
      return RetryClass.permanent;
    case DioExceptionType.unknown:
      // A dropped connection surfaces as `unknown` wrapping an I/O error:
      // a SocketException, or an HttpException such as "connection closed
      // before full header was received" when the server vanished after
      // reading the body.
      return error.error is IOException
          ? RetryClass.transient
          : RetryClass.permanent;
    // Newer dio versions add exception types (e.g. `transformTimeout` in
    // 5.10.0). Treat anything unknown as non-retryable so the SDK keeps
    // compiling against every dio 5.x.
    default:
      return RetryClass.permanent;
  }
}
