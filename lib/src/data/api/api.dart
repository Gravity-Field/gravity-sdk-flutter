import 'dart:convert';

import 'package:dio/dio.dart' hide Options;
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/gravity_interceptor.dart';
import 'package:gravity_sdk/src/data/api/retry_class.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:gravity_sdk/src/utils/time_format.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'content_ids_response.dart';

class Api {
  final _dio = Dio();

  String get baseUrl => GravitySDK.instance.proxyUrl ?? 'https://evs-01.gravityfield.ai/v2';

  /// Pauses between transient retry attempts. An empty list disables retries.
  @visibleForTesting
  static List<Duration> retryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// Pause used between retries; tests replace it to avoid real waits.
  @visibleForTesting
  static Future<void> Function(Duration delay) sleep = (delay) =>
      Future<void>.delayed(delay);

  /// Fired after every successful online request (event/visit/choose).
  /// The outbox treats it as a "network is back" signal.
  static void Function()? onRequestSucceeded;

  /// Runs [send], retrying transient and server failures per [retryDelays]
  /// while the next pause still fits into the retry budget — by default
  /// [GravitySDK.staleContentTimeout], the time a response stays worth
  /// acting on. [budget] overrides it for call sites with their own limit.
  Future<T> _withRetry<T>(
    Future<T> Function() send, {
    bool signalSuccess = true,
    bool retry = true,
    Duration? budget,
  }) async {
    final deadline = Clock.now().add(budget ?? GravitySDK.instance.staleContentTimeout);
    var attempt = 0;
    while (true) {
      final T result;
      try {
        result = await send();
      } catch (error) {
        if (!retry) rethrow;
        if (classifyError(error) == RetryClass.permanent) rethrow;
        if (attempt >= retryDelays.length) rethrow;
        final delay = retryDelays[attempt];
        if (Clock.now().add(delay).isAfter(deadline)) rethrow;
        attempt++;
        await sleep(delay);
        continue;
      }
      // Outside the retry try/catch on purpose: a listener that throws must
      // never turn a delivered request into a failure, nor make it re-send.
      if (signalSuccess) {
        try {
          onRequestSucceeded?.call();
        } catch (_) {}
      }
      return result;
    }
  }

  Api() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 60)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveDataWhenStatusError = true;

    _dio.interceptors.add(GravityInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(
        TalkerDioLogger(
          talker: talker,
          settings: const TalkerDioLoggerSettings(
            printRequestHeaders: true,
            printRequestData: true,
            printResponseHeaders: true,
            printResponseMessage: true,
            printResponseData: true,
          ),
        ),
      );
    }
  }

  Future<ContentResponse> chooseByCampaignId({
    required String campaignId,
    User? user,
    required PageContext context,
    required Options options,
    required ContentSettings contentSettings,
    List<RtRule>? rules,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': [
        {
          'campaignId': campaignId,
          'option': contentSettings.toJson(),
          if (rules != null) 'rules': rules.map((r) => r.toJson()).toList(),
        },
      ],
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> chooseBySelector({
    required String selector,
    User? user,
    String? templateId,
    required PageContext context,
    required Options options,
    required ContentSettings contentSettings,
    List<RtRule>? rules,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': [
        {
          'selector': selector,
          'option': contentSettings.toJson(),
          if (rules != null) 'rules': rules.map((r) => r.toJson()).toList(),
        },
      ],
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> chooseByGroup({
    required String group,
    User? user,
    required PageContext context,
    required Options options,
    required ContentSettings contentSettings,
    List<RtRule>? rules,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': [
        {
          'group': group,
          'option': contentSettings.toJson(),
          if (rules != null) 'rules': rules.map((r) => r.toJson()).toList(),
        },
      ],
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> chooseBatch({
    required List<Map<String, dynamic>> dataArray,
    User? user,
    required PageContext context,
    required Options options,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': dataArray,
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    return ContentResponse.fromJson(response.data);
  }

  Future<CampaignIdsResponse> visit(User? user, PageContext context, Options options) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'device': device.toJson(),
      'type': 'screenview',
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/visit', data: data),
    );
    return CampaignIdsResponse.fromJson(response.data);
  }

  /// Builds the `/event` body exactly as it goes over the wire, as plain JSON.
  /// Events without their own `eventTime` get [now] (UTC, RFC 3339) — the
  /// moment the caller raised the event, which may be well before this runs
  /// when the call waited for the session.
  Future<Map<String, dynamic>> buildEventBody(
    List<TriggerEvent> events,
    User? user,
    PageContext context,
    Options options, {
    DateTime? now,
  }) async {
    final device = await DeviceUtils.instance.getDevice();
    final eventTime = formatEventTime(now ?? Clock.now());

    final raw = {
      'sec': GravitySDK.instance.section,
      'device': device.toJson(),
      'data': [
        for (final event in events)
          () {
            final json = event.toJson();
            return {
              ...json,
              if (json['eventTime'] == null) 'eventTime': eventTime,
            };
          }(),
      ],
      'user': user?.toJson() ?? <String, dynamic>{},
      'ctx': context.toJson(),
      'options': options.toJson(),
    };
    // Normalise nested objects (e.g. CartItem) into plain maps so the body can
    // be persisted and compared byte-for-byte with what Dio sends.
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  /// Sends a body produced by [buildEventBody]. [deferred] is used by the
  /// outbox: no transient retry (the outbox has its own backoff) and no
  /// success signal (it would re-trigger the outbox).
  Future<CampaignIdsResponse> postEventBody(
    Map<String, dynamic> body, {
    bool deferred = false,
  }) async {
    final response = await _withRetry(
      () => _dio.post('$baseUrl/event', data: body),
      signalSuccess: !deferred,
      retry: !deferred,
    );
    return CampaignIdsResponse.fromJson(response.data);
  }

  Future<void> triggerEventUrl(String url, {bool deferred = false}) async {
    await _withRetry(
      () => _dio.get(url),
      signalSuccess: false,
      retry: !deferred,
      budget: const Duration(seconds: 10),
    );
  }

  Future<(ContentResponse, Map<String, dynamic>)> chooseByCampaignIdWithDetails({
    required String campaignId,
    User? user,
    required PageContext context,
    required Options options,
    required ContentSettings contentSettings,
    List<RtRule>? rules,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': [
        {
          'campaignId': campaignId,
          'option': contentSettings.toJson(),
          if (rules != null) 'rules': rules.map((r) => r.toJson()).toList(),
        },
      ],
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    final json = response.data as Map<String, dynamic>;
    return (ContentResponse.fromJson(json), json);
  }

  Future<(ContentResponse, Map<String, dynamic>)> chooseBySelectorWithDetails({
    required String selector,
    User? user,
    required PageContext context,
    required Options options,
    required ContentSettings contentSettings,
    List<RtRule>? rules,
  }) async {
    final device = await DeviceUtils.instance.getDevice();

    final data = {
      'sec': GravitySDK.instance.section,
      'data': [
        {
          'selector': selector,
          'option': contentSettings.toJson(),
          if (rules != null) 'rules': rules.map((r) => r.toJson()).toList(),
        },
      ],
      'device': device.toJson(),
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _withRetry(
      () => _dio.post('$baseUrl/choose', data: data),
    );
    final json = response.data as Map<String, dynamic>;
    return (ContentResponse.fromJson(json), json);
  }
}
