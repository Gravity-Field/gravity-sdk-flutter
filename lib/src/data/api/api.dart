import 'package:dio/dio.dart' hide Options;
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/gravity_interceptor.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../../models/external/user.dart';
import 'content_response.dart';

class Api {
  final _dio = Dio();

  String get baseUrl => GravitySDK.instance.proxyUrl ?? 'https://mock.apidog.com/m1/807903-786789-default';

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

  Future<ContentResponse> choose({
    User? user,
    String? templateId,
    PageContext? context,
    required Options options,
    required ContentSettings contentSettings,
  }) async {
    final data = {
      'sec': GravitySDK.instance.section,
      'device': GravitySDK.instance.device.toJson(),
      'user': user?.toJson(),
      'ctx': context?.toJson(),
      'options': options.toJson(),
      'contentSettings': contentSettings.toJson(),
    };

    final response = await _dio.post('$baseUrl/choose', queryParameters: {'templateId': templateId}, data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> visit(User? user, PageContext context, Options options) async {
    final data = {
      'sec': GravitySDK.instance.section,
      'device': GravitySDK.instance.device.toJson(),
      'type': 'screenview',
      'user': user?.toJson(),
      'ctx': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _dio.post('$baseUrl/visit', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> event(List<TriggerEvent> events, User? user, PageContext context, Options options) async {
    final data = {
      'sec': GravitySDK.instance.section,
      'device': GravitySDK.instance.device.toJson(),
      'data': events
          .map(
            (e) => e.toJson(),
          )
          .toList(),
      'user': user?.toJson(),
      'context': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _dio.post('$baseUrl/event', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<void> triggerEventUrl(String url) async {
    await _dio.get(url);
  }
}
