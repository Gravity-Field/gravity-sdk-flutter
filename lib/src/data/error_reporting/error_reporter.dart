import 'dart:async';
import 'dart:io';

import 'diagnostic_url_sanitizer.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:gravity_sdk/src/version.dart';

class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  /// Unit/widget suites disable live transport and use the send override
  /// when they need to inspect payloads or control delivery completion.
  @visibleForTesting
  static bool disableNetworkForTests = false;

  /// Receives every report that passed the rate limit, whether or not it is
  /// sent. Failures the SDK swallows on purpose are only observable here.
  @visibleForTesting
  static void Function(String section, Map<String, dynamic> payload)? observer;

  /// Takes the place of the network send, so a test can see which reports
  /// would really go out. An optional Future controls successful completion.
  /// Checked before [disableNetworkForTests].
  @visibleForTesting
  static FutureOr<void> Function(Map<String, dynamic> payload)? sendOverride;

  @visibleForTesting
  static Future<String?> Function()? readStoredUserIdForTests;

  static const String _endpoint = 'https://sdk-sentry.gravityfield.ai/error';
  static const int _maxErrorsPerMinute = 10;
  static const Duration _window = Duration(seconds: 60);
  static const int _maxMessageLength = 1000;
  static const int _maxStacktraceLength = 5000;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  final List<DateTime> _recentTimestamps = [];
  // Report hash -> when delivery last completed successfully, oldest first. Entries leave one by
  // one as they age out of the window, so a burst of distinct reports never
  // lets every duplicate through at once.
  final Map<int, DateTime> _recentHashes = {};
  final Set<int> _pendingHashes = {};
  static const _identityTimeout = Duration(seconds: 3);
  Future<User>? _identityRead;
  int? _identityReadGeneration;
  Future<String>? _deviceRead;

  Future<User> _readIdentity() {
    final generation = SessionManager.instance.generation;
    if (_identityRead != null && _identityReadGeneration == generation) return _identityRead!;
    final original = SessionManager.instance.getUserAfterIdentityUpdates(
      readStoredUserId: readStoredUserIdForTests,
    );
    late final Future<User> attempt;
    attempt = original.timeout(_identityTimeout, onTimeout: () => const User()).catchError((Object error) {
      if (identical(_identityRead, attempt)) _identityRead = null;
      return const User();
    });
    _identityRead = attempt;
    _identityReadGeneration = generation;
    // Timeouts do not cancel platform reads. Share their bounded result rather
    // than enqueue another FIFO read per report; a late valid result recovers.
    original.then((user) {
      if (generation == SessionManager.instance.generation && identical(_identityRead, attempt)) {
        _identityRead = Future.value(user);
      }
    }, onError: (Object error) {
      if (identical(_identityRead, attempt)) _identityRead = null;
    }).ignore();
    return attempt;
  }

  Future<String> _readDeviceId() {
    final cached = _nonEmpty(DeviceUtils.instance.deviceIdCache);
    if (cached != null) return Future.value(cached);
    if (_deviceRead != null) return _deviceRead!;
    final original = DeviceUtils.instance.getDeviceId();
    late final Future<String> attempt;
    attempt = original.timeout(_identityTimeout, onTimeout: () => 'no-uid').catchError((Object error) {
      if (identical(_deviceRead, attempt)) _deviceRead = null;
      return 'no-uid';
    });
    _deviceRead = attempt;
    original.then((_) {}, onError: (Object error) {
      if (identical(_deviceRead, attempt)) _deviceRead = null;
    }).ignore();
    return attempt;
  }

  /// Admits at most ten attempts per minute, reserving pending hashes and
  /// deduplicating successful deliveries for 60 seconds after completion.
  /// Failed attempts spend budget but allow a retry. Whatever the caller passes,
  /// every http(s) URL in the report loses its query, fragment and credentials
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
    // No transport or test sink can consume this report. Avoid platform work
    // and timeout timers in a widget zone that is about to be disposed.
    if (disableNetworkForTests && sendOverride == null && observer == null) return;
    int? admittedHash;
    try {
      final cleanSection = _sanitizeUrls(section);
      final cleanMessage = _sanitizeBounded(message, _maxMessageLength);
      final cleanStacktrace = _sanitizeBounded(stacktrace ?? '', _maxStacktraceLength);
      final hash = Object.hash(cleanMessage, cleanStacktrace);
      final now = Clock.now();
      _recentTimestamps.removeWhere((t) => now.difference(t) >= _window);
      if (_pendingHashes.contains(hash) || _isRecentDuplicate(hash, now) ||
          _recentTimestamps.length >= _maxErrorsPerMinute ||
          _pendingHashes.length >= _maxErrorsPerMinute) {
        return;
      }
      _recentTimestamps.add(now);
      _pendingHashes.add(hash);
      admittedHash = hash;

      final payload = {
        'message': cleanMessage,
        'level': level,
        'sec': _sanitizeUrls(GravitySDK.instance.section),
        // The endpoint answers 400 to a report without a non-empty uid. This
        // is the server uid, resolved from storage or the SDK device id on
        // cold start, never the custom id the app passed to setUser().
        'uid': SessionManager.instance.userId,
        'ses': _nonEmpty(SessionManager.instance.sessionId) ?? _nonEmpty(GravitySDK.instance.user?.ses) ?? 'no-session',
        'sdkVersion': packageVersion,
        'sdkType': 'flutter',
        'platform': Platform.operatingSystem,
        'extra': <String, dynamic>{
          for (final entry in (extra ?? const <String, dynamic>{}).entries) entry.key: _sanitizeValue(entry.value),
        },
        // `sec` above is the app section of the wire contract; the part of
        // the SDK that reported goes here.
        'tags': <String, String>{
          for (final entry in (tags ?? const <String, String>{}).entries) entry.key: _sanitizeUrls(entry.value),
          'section': cleanSection,
        },
        'stacktrace': cleanStacktrace,
      };

      final delivery = _nonEmpty(payload['uid'] as String?) != null
          ? _send(cleanSection, payload)
          : _resolveIdentityAndSend(cleanSection, payload);
      if (delivery == null) {
        _pendingHashes.remove(hash);
      } else {
        delivery.whenComplete(() => _pendingHashes.remove(hash)).ignore();
      }
    } catch (_) {
      if (admittedHash != null) _pendingHashes.remove(admittedHash);
    }
  }

  static String? _nonEmpty(String? value) => value == null || value.isEmpty ? null : value;

  Future<void> _resolveIdentityAndSend(
    String section,
    Map<String, dynamic> payload,
  ) async {
    String? storedUid;
    try {
      // Join accepted identity writes without waiting for the network session:
      // this report may be describing that very initialization's failure.
      final user = await _readIdentity();
      storedUid = user.uid;
      payload['ses'] = _nonEmpty(user.ses) ?? payload['ses'];
    } catch (_) {
      // The device path can still resolve an identity from its memory cache.
    }
    var uid = _nonEmpty(storedUid);
    if (uid == null) {
      try {
        uid = await _readDeviceId();
      } catch (_) {
        // Storage failure must not prevent reporting that failure itself.
      }
    }
    payload['uid'] = _nonEmpty(uid) ?? 'no-uid';
    await _send(section, payload);
  }

  Future<void>? _send(String cleanSection, Map<String, dynamic> payload) {
    try {
      final hash = Object.hash(payload['message'], payload['stacktrace']);
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
        final completion = send(payload);
        if (completion is Future<void>) {
          return completion.then<void>((_) {
            _recentHashes[hash] = Clock.now();
          });
        }
        _recentHashes[hash] = Clock.now();
        return null;
      }
      if (disableNetworkForTests) return null;
      return _dio.post(_endpoint, data: payload).then<void>((_) {
        _recentHashes[hash] = Clock.now();
      });
    } catch (_) {
      return null;
    }
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
      message: messageForError(error),
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

  /// HTTP exception messages may quote a response body. Describe only the
  /// request and status, including at higher layers that report it again.
  static String messageForError(Object error) {
    if (error is DioException) {
      final request = error.requestOptions;
      final url = _sanitizeUrls(request.uri.toString());
      return 'DioException [${error.type.name}] ${request.method} $url -> ${error.response?.statusCode ?? 'no response'}';
    }
    return error.toString();
  }

  String _sanitizeBounded(String text, int maxLength) =>
      _truncate(DiagnosticUrlSanitizer.sanitize(text, inputBound: maxLength * 10), maxLength);

  static String _sanitizeUrls(String text) => DiagnosticUrlSanitizer.sanitize(text);

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
  static Map<String, dynamic> _readOnlyCopy(Map<String, dynamic> payload) => Map<String, dynamic>.unmodifiable({
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

  bool _isRecentDuplicate(int hash, DateTime now) {
    _recentHashes.removeWhere((_, sentAt) => now.difference(sentAt) >= _window);
    return _recentHashes.containsKey(hash);
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}
