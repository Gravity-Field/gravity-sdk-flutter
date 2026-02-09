import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/version.dart';

class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  static const String _endpoint = 'https://sdk-sentry.gravityfield.ai/error';
  static const int _maxErrorsPerMinute = 10;
  static const int _maxMessageLength = 1000;
  static const int _maxStacktraceLength = 5000;
  static const int _maxResponseBodyLength = 500;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  final List<DateTime> _recentTimestamps = [];
  final Set<int> _recentHashes = {};

  void report({
    required String message,
    required String level,
    required String section,
    String? stacktrace,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) {
    try {
      if (!_checkRateLimit()) return;
      if (!_checkDedup(message, stacktrace)) return;

      final payload = {
        'message': _truncate(message, _maxMessageLength),
        'level': level,
        'sec': GravitySDK.instance.section,
        'uid': SessionManager.instance.userId,
        'ses': SessionManager.instance.sessionId,
        'sdkVersion': packageVersion,
        'sdkType': 'flutter',
        'platform': Platform.operatingSystem,
        'extra': extra ?? {},
        'tags': tags ?? {},
        'stacktrace': _truncate(stacktrace ?? '', _maxStacktraceLength),
      };

      _dio.post(_endpoint, data: payload).ignore();
    } catch (_) {}
  }

  void reportDioError({
    required DioException error,
    required String section,
    StackTrace? stackTrace,
  }) {
    report(
      message: error.message ?? error.toString(),
      level: error.type == DioExceptionType.badResponse ? 'warning' : 'error',
      section: section,
      stacktrace: stackTrace?.toString(),
      extra: {
        'url': error.requestOptions.uri.toString(),
        'httpMethod': error.requestOptions.method,
        'httpStatus': error.response?.statusCode,
        'dioType': error.type.name,
        'responseBody': _truncate(
          error.response?.data?.toString() ?? '',
          _maxResponseBodyLength,
        ),
      },
      tags: {'category': 'network'},
    );
  }

  bool _checkRateLimit() {
    final now = DateTime.now();
    _recentTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (_recentTimestamps.length >= _maxErrorsPerMinute) return false;
    _recentTimestamps.add(now);
    return true;
  }

  bool _checkDedup(String message, String? stacktrace) {
    final hash = Object.hash(message, stacktrace);
    if (_recentHashes.contains(hash)) return false;
    _recentHashes.add(hash);
    if (_recentHashes.length > 100) {
      _recentHashes.clear();
    }
    return true;
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}
