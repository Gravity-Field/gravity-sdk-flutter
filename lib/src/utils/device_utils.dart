import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:ua_client_hints/ua_client_hints.dart';
import 'package:uuid/v4.dart';

import '../data/prefs/prefs.dart';
import '../models/internal/device.dart';

class DeviceUtils {
  DeviceUtils._();

  static final DeviceUtils instance = DeviceUtils._();

  String? userAgentCache;
  String? deviceIdCache;

  Future<Device> getDevice() async {
    try {
      final userAgent = await _getUserAgent();
      final deviceId = await _getDeviceId();
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      final permission = GravitySDK.instance.notificationPermissionStatus;

      return Device(
        userAgent: userAgent,
        id: deviceId,
        tracking: status.name,
        permission: permission.name,
      );
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'error',
        section: 'DeviceUtils.getDevice',
        stacktrace: stackTrace.toString(),
        tags: {'category': 'device'},
      );
      rethrow;
    }
  }

  Future<String> _getUserAgent() async {
    if (userAgentCache != null) {
      return userAgentCache!;
    }
    final ua = await userAgent();
    userAgentCache = ua;
    return ua;
  }

  Future<String> _getDeviceId() async {
    if (deviceIdCache != null) {
      return deviceIdCache!;
    }

    String? deviceId = await Prefs.instance.getDeviceId();
    if (deviceId == null) {
      deviceId = UuidV4().generate();
      await Prefs.instance.setDeviceId(deviceId);
    }
    deviceIdCache = deviceId;
    return deviceId;
  }
}
