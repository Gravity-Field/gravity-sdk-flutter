import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/version.dart';

class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  /// Widget tests run under FakeAsync where the fire-and-forget Dio call
  /// leaves a pending timer that fails the test; there is no transport seam
  /// to mock, so tests opt out of the network send entirely.
  @visibleForTesting
  static bool disableNetworkForTests = false;

  /// Receives every report that passed the rate limit, whether or not it is
  /// sent. Failures the SDK swallows on purpose are only observable here.
  @visibleForTesting
  static void Function(String section, Map<String, dynamic> payload)? observer;

  /// Takes the place of the network send, so a test can see which reports
  /// would really go out. Checked before [disableNetworkForTests].
  @visibleForTesting
  static void Function(Map<String, dynamic> payload)? sendOverride;

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

      final observe = observer;
      if (observe != null) {
        // It only watches: it may neither edit the report on its way out — nor
        // the caller's own tags and extra, which it shares — nor decide, by
        // throwing, that the report is not worth sending.
        try {
          observe(section, _readOnlyCopy(payload));
        } catch (_) {}
      }

      final send = sendOverride;
      if (send != null) {
        send(payload);
        return;
      }
      if (disableNetworkForTests) return;
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

  /// A view of [payload] that is read-only all the way down: the nested maps
  /// and lists are the caller's own objects, so handing them out as they are
  /// would let a watcher rewrite what the app passed in.
  static Map<String, dynamic> _readOnlyCopy(Map<String, dynamic> payload) =>
      Map<String, dynamic>.unmodifiable({
        for (final entry in payload.entries) entry.key: _readOnlyValue(entry.value),
      });

  static Object? _readOnlyValue(Object? value) {
    if (value is Map) {
      return Map<Object?, Object?>.unmodifiable({
        for (final entry in value.entries) entry.key: _readOnlyValue(entry.value),
      });
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_readOnlyValue));
    }
    return value;
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
