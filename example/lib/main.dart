import 'package:example/src/core/services/push_notification_service.dart';
import 'package:example/src/core/widgets/custom_product_widget_builder.dart';
import 'package:example/src/features/home/home_page.dart';
import 'package:example/src/features/webview/webview_page.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GravitySDK.instance.initialize(
    apiKey: 'YzYyMTk2YzFmYTMzYmI5YjE0ZGQ3NjAyZjM4MDc1Yzk3ZDRlM2I2ZDZjNjc0MzI3YjViZTcyYTZjODI5ZWQ0YQ==',
    section: '6819e7c0d7303f0f6b0ef263',
    productWidgetBuilder: CustomProductWidgetBuilder(),
    gravityEventCallback: (event) {
      debugPrint('Gravity SDK Event: ${event.runtimeType}');

      if (event is FollowUrlEvent) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => WebViewPage(url: event.url)));
        }
      }

      if (event is FollowDeeplinkEvent) {
        debugPrint('Follow Deeplink: ${event.deeplink}');
      }

      if (event is RequestPushEvent) {
        debugPrint('Received RequestPushEvent - requesting push permissions');
        PushNotificationService.instance.requestPushPermission();
      }
    },
  );

  await PushNotificationService.instance.updateCurrentStatus();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(navigatorKey: navigatorKey, home: const HomePage());
  }
}
