import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
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
  static const Duration _window = Duration(seconds: 60);
  static const int _maxMessageLength = 1000;
  static const int _maxStacktraceLength = 5000;

  // An http(s) URL inside free text. Up to its query or fragment it ends at
  // whitespace, quotes, brackets or a comma, which end a URL in messages and
  // stack traces far more often than they belong to one; a bracketed IPv6
  // host is the one place square brackets are part of it, so a bracket pair
  // is taken whole. The query and fragment are dropped anyway, so from `?`
  // or `#` on everything up to whitespace or a quote goes with them: a
  // comma or bracket inside a query must not leave its tail behind.
  static final RegExp _urlPattern = RegExp(
    r'''https?://(?:\[[^\]\s]*\]|[^\s"'<>()\[\]{},?#])+(?:[?#][^\s"'<>]*)?''',
    caseSensitive: false,
  );

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  final List<DateTime> _recentTimestamps = [];
  // Report hash -> when it was last sent, oldest first. Entries leave one by
  // one as they age out of the window, so a burst of distinct reports never
  // lets every duplicate through at once.
  final Map<int, DateTime> _recentHashes = {};

  /// Sends a report unless it repeats one sent within the last minute or ten
  /// reports went out within it already. Whatever the caller passes, every
  /// http(s) URL in the report loses its query, fragment and credentials
  /// before anything else sees it: those are where user ids, tokens and
  /// tracking parameters travel.
  void report({
    required String message,
    required String level,
    required String section,
    String? stacktrace,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) {
    try {
      final cleanSection = _sanitizeUrls(section);
      final cleanMessage = _truncate(_sanitizeUrls(message), _maxMessageLength);
      final cleanStacktrace = _truncate(_sanitizeUrls(stacktrace ?? ''), _maxStacktraceLength);

      // Duplicates are checked first so that they do not spend the budget
      // meant for distinct failures, and a report is remembered only once it
      // is really let through: one the budget turned away may come again.
      final now = Clock.now();
      final hash = Object.hash(cleanMessage, cleanStacktrace);
      if (_isRecentDuplicate(hash, now)) return;
      if (!_checkRateLimit(now)) return;
      _recentHashes[hash] = now;

      final payload = {
        'message': cleanMessage,
        'level': level,
        'sec': GravitySDK.instance.section,
        // No uid: the session id is short-lived and enough for the backend to
        // find the rest, while the uid would follow the user across sessions.
        'ses': SessionManager.instance.sessionId,
        'sdkVersion': packageVersion,
        'sdkType': 'flutter',
        'platform': Platform.operatingSystem,
        'extra': <String, dynamic>{
          for (final entry in (extra ?? const <String, dynamic>{}).entries)
            entry.key: _sanitizeValue(entry.value),
        },
        // `sec` above is the app section of the wire contract; the part of
        // the SDK that reported goes here.
        'tags': <String, String>{
          for (final entry in (tags ?? const <String, String>{}).entries)
            entry.key: _sanitizeUrls(entry.value),
          'section': cleanSection,
        },
        'stacktrace': cleanStacktrace,
      };

      final observe = observer;
      if (observe != null) {
        // It only watches: it may neither edit the report on its way out — nor
        // the caller's own tags and extra, which it shares — nor decide, by
        // throwing, that the report is not worth sending.
        try {
          observe(cleanSection, _readOnlyCopy(payload));
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

  /// Reports a failed HTTP request. The message is built from the request
  /// alone: the error text and the response body may quote what the server
  /// answered, which can be anything, personal data included.
  void reportDioError({
    required DioException error,
    required String section,
    StackTrace? stackTrace,
  }) {
    final request = error.requestOptions;
    final url = _sanitizeUrls(request.uri.toString());
    final status = error.response?.statusCode;
    report(
      message: 'DioException [${error.type.name}] ${request.method} $url -> ${status ?? 'no response'}',
      level: error.type == DioExceptionType.badResponse ? 'warning' : 'error',
      section: section,
      stacktrace: stackTrace?.toString(),
      extra: {
        'url': url,
        'httpMethod': request.method,
        'httpStatus': status,
        'dioType': error.type.name,
      },
      tags: {'category': 'network'},
    );
  }

  /// [text] with every http(s) URL in it cut down to scheme, host, port and
  /// path.
  static String _sanitizeUrls(String text) =>
      text.replaceAllMapped(_urlPattern, (match) => _stripUrl(match[0]!));

  static String _stripUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      // Not parseable as a whole: drop what follows the path and whatever
      // precedes an `@` in the authority by hand.
      final cut = url.split(RegExp('[?#]')).first;
      return cut.replaceFirst(RegExp(r'^([a-zA-Z]+://)[^/@]*@'), r'$1');
    }
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://$host$port${uri.path}';
  }

  /// A copy of [value] with [_sanitizeUrls] applied to every string in it,
  /// however deep. The caller's maps and lists are left as they were.
  static Object? _sanitizeValue(Object? value) {
    if (value is String) return _sanitizeUrls(value);
    if (value is Map) {
      return <Object?, Object?>{
        for (final entry in value.entries) entry.key: _sanitizeValue(entry.value),
      };
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
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

  bool _checkRateLimit(DateTime now) {
    _recentTimestamps.removeWhere((t) => now.difference(t) > _window);
    if (_recentTimestamps.length >= _maxErrorsPerMinute) return false;
    _recentTimestamps.add(now);
    return true;
  }

  bool _isRecentDuplicate(int hash, DateTime now) {
    _recentHashes.removeWhere((_, sentAt) => now.difference(sentAt) > _window);
    return _recentHashes.containsKey(hash);
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}
