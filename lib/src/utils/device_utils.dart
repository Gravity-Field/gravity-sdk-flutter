import 'package:ua_client_hints/ua_client_hints.dart';
import 'package:uuid/v4.dart';

import '../data/prefs/prefs.dart';

class DeviceUtils {
  static Future<String> getUserAgent() async {
    final ua = await userAgent();
    return ua;
  }

  static Future<String> getDeviceId() async {
    String? deviceId = await Prefs.instance.getDeviceId();
    if (deviceId == null) {
      deviceId = UuidV4().generate();
      await Prefs.instance.setDeviceId(deviceId);
    }
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
