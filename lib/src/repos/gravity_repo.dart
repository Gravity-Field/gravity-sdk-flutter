import 'dart:math';

import 'package:dio/dio.dart';
import 'package:gravity_sdk/src/models/delivery_type.dart';

class GravityRepo {
  final dio = Dio();

  GravityRepo() {
    dio.options.baseUrl = 'https://api.gravitysdk.org';
  }

  Future<void> sendEvent() {
    return Future.delayed(const Duration(seconds: 0));
  }

  Future<DeliveryType> getContent() async {
    final random = Random();
    return DeliveryType.values[random.nextInt(DeliveryType.values.length - 1)];
  }
}
