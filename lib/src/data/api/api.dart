import 'package:dio/dio.dart' hide Options;
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/gravity_interceptor.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../models/external/user.dart';
import 'content_response.dart';

class Api {
  final _dio = Dio();

  Api() {
    _dio.options
      ..baseUrl = 'https://mock.apidog.com/m1/807903-786789-default'
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 60)
      ..sendTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(GravityInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestBody: true,
        requestHeader: true,
      ));
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

    final response = await _dio.post('/choose', queryParameters: {'templateId': templateId}, data: data);
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

    final response = await _dio.post('/visit', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> event(User? user, PageContext context, Options options) async {
    final data = {
      'sec': GravitySDK.instance.section,
      'device': GravitySDK.instance.device.toJson(),
      'user': user?.toJson(),
      'context': context.toJson(),
      'options': options.toJson(),
    };

    final response = await _dio.post('/event', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<void> triggerEventUrl(String url) async {
    await _dio.get(url);
  }
}
