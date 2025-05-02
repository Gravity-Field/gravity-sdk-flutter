import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
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

    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestBody: true,
        requestHeader: true,
      ));
    }
  }

  Future<ContentResponse> choose(String templateId) async {
    final response = await _dio.post('/choose', queryParameters: {'templateId': templateId});
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> visit(User? user, PageContext context) async {
    final data = {
      'user': user?.toJson(),
      'context': context.toJson(),
    };

    final response = await _dio.post('/visit', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<ContentResponse> event(User? user, PageContext context) async {
    final data = {
      'user': user?.toJson(),
      'context': context.toJson(),
    };

    final response = await _dio.post('/event', data: data);
    return ContentResponse.fromJson(response.data);
  }

  Future<void> triggerEventUrl(String url) async {
    await _dio.get(url);
  }
}
