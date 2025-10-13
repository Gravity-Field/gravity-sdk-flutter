import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<NotificationPermissionStatus> getNotificationStatus() async {
    await _initializeNotifications();

    var status = await Permission.notification.status;

    if (!status.isGranted) {
      if (_flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>() !=
          null) {
        final iosImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()!;

        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      status = await Permission.notification.request();
    }

    if (status.isGranted) {
      return NotificationPermissionStatus.granted;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      return NotificationPermissionStatus.denied;
    } else {
      return NotificationPermissionStatus.unknown;
    }
  }

  Future<void> requestPushPermission() async {
    final status = await Permission.notification.request();

    NotificationPermissionStatus permissionStatus;
    if (status.isGranted) {
      permissionStatus = NotificationPermissionStatus.granted;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      permissionStatus = NotificationPermissionStatus.denied;
    } else {
      permissionStatus = NotificationPermissionStatus.unknown;
    }

    GravitySDK.instance.setNotificationPermissionStatus(permissionStatus);
  }

  Future<void> updateCurrentStatus() async {
    final currentStatus = await getNotificationStatus();
    GravitySDK.instance.setNotificationPermissionStatus(currentStatus);
  }
}
