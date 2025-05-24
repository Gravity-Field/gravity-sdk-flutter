import 'dart:io';

import 'package:advertising_id/advertising_id.dart';
import 'package:android_id/android_id.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:ua_client_hints/ua_client_hints.dart';

class DeviceUtils {
  static Future<Map<String, dynamic>> getUserAgent() async {
    final ua = await userAgentData();

    return {
      'platform': ua.platform,
      'platformVersion': ua.platformVersion,
      'architecture': ua.architecture,
      'model': ua.model,
      'brand': ua.brand,
      'version': ua.version,
      'mobile': ua.mobile.toString(),
      'device': ua.device,
      'package': {
        'appName': ua.package.appName,
        'appVersion': ua.package.appVersion,
        'packageName': ua.package.packageName,
        'buildNumber': ua.package.buildNumber,
      }
    };
  }

  static Future<String?> getDeviceId(bool useAdvertisingId) async {
    if (Platform.isIOS) {
      return _getDeviceIdForIOS(useAdvertisingId);
    } else if (Platform.isAndroid) {
      return _getDeviceIdForAndroid(useAdvertisingId);
    } else {
      return null;
    }
  }

  static Future<String?> _getDeviceIdForIOS(bool useAdvertisingId) async {
    String? deviceId;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor;
    } on PlatformException {
      deviceId = null;
    }

    print('DeviceId id is $deviceId');

    if (!useAdvertisingId) {
      return deviceId;
    }

    TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;

    // if (status == TrackingStatus.notDetermined) {
    //   print('Request tracking authorization');
    //   status = await AppTrackingTransparency.requestTrackingAuthorization();
    // }
    //
    // print('Tracking status is $status');

    if (status == TrackingStatus.authorized) {
      String? advertisingId = await AppTrackingTransparency.getAdvertisingIdentifier();
      print('Advertising id is $advertisingId');
      return advertisingId;
    } else {
      return deviceId;
    }
  }

  static Future<String?> _getDeviceIdForAndroid(bool useAdvertisingId) async {
    String? deviceId;

    try {
      final androidIdPlugin = AndroidId();
      deviceId = await androidIdPlugin.getId();
    } on PlatformException {
      deviceId = null;
    }

    print('DeviceId id is $deviceId');

    if (!useAdvertisingId) {
      return deviceId;
    }

    final isLimitAdTrackingEnabled = await AdvertisingId.isLimitAdTrackingEnabled;

    print('isLimitAdTrackingEnabled is $isLimitAdTrackingEnabled');

    if (isLimitAdTrackingEnabled == false) {
      try {
        String? advertisingId = await AdvertisingId.id(true);
        print('Advertising id is $advertisingId');
        return advertisingId;
      } on PlatformException {
        return deviceId;
      }
    } else {
      return deviceId;
    }
  }
}
