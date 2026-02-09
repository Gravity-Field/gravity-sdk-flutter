import 'package:dio/dio.dart';

String categorizeError(Object error) {
  if (error is DioException) return 'network';
  if (error is TypeError || error is FormatException) return 'parsing';
  return 'unknown';
}

String errorLevel(Object error) {
  if (error is DioException) {
    return error.type == DioExceptionType.badResponse ? 'warning' : 'error';
  }
  return 'error';
}
