import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
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
    final userAgent = await _getUserAgent();
    final deviceId = await _getDeviceId();
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    final permission = await GravitySDK.instance.notificationPermissionStatus;

    return Device(
      userAgent: userAgent,
      id: deviceId,
      tracking: status.name,
      permission: permission.name,
    );
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

// static Future<String?> getDeviceId(bool useAdvertisingId) async {
//   if (Platform.isIOS) {
//     return _getDeviceIdForIOS(useAdvertisingId);
//   } else if (Platform.isAndroid) {
//     return _getDeviceIdForAndroid(useAdvertisingId);
//   } else {
//     return null;
//   }
// }
//
// static Future<String?> _getDeviceIdForIOS(bool useAdvertisingId) async {
//   String? deviceId;
//
//   try {
//     DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//     deviceId = iosInfo.identifierForVendor;
//   } on PlatformException {
//     deviceId = null;
//   }
//
//   if (!useAdvertisingId) {
//     return deviceId;
//   }
//
//   TrackingStatus status = await AppTrackingTransparency.trackingAuthorizationStatus;
//
//   if (status == TrackingStatus.authorized) {
//     String? advertisingId = await AppTrackingTransparency.getAdvertisingIdentifier();
//     return advertisingId;
//   } else {
//     return deviceId;
//   }
// }
//
// static Future<String?> _getDeviceIdForAndroid(bool useAdvertisingId) async {
//   String? deviceId;
//
//   try {
//     final androidIdPlugin = AndroidId();
//     deviceId = await androidIdPlugin.getId();
//   } on PlatformException {
//     deviceId = null;
//   }
//
//   if (!useAdvertisingId) {
//     return deviceId;
//   }
//
//   final isLimitAdTrackingEnabled = await AdvertisingId.isLimitAdTrackingEnabled;
//
//   if (isLimitAdTrackingEnabled == false) {
//     try {
//       String? advertisingId = await AdvertisingId.id(true);
//       return advertisingId;
//     } on PlatformException {
//       return deviceId;
//     }
//   } else {
//     return deviceId;
//   }
// }
}
