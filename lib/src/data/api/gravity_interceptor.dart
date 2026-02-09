import 'package:dio/dio.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';

class GravityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final apiKey = GravitySDK.instance.apiKey;
    options.headers['Authorization'] = 'Bearer $apiKey';
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ErrorReporter.instance.reportDioError(
      error: err,
      section: 'Api.${err.requestOptions.path}',
    );
    super.onError(err, handler);
  }
}
