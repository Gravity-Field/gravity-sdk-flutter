import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PresentationLockPrefs {
  static const _key = 'gravity_presentation_locked';

  static Future<void> _lastWrite = Future<void>.value();

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) ?? false) {
      GravitySDK.instance.lockPresentation();
    }
  }

  static Future<void> save(bool locked) {
    _lastWrite = _lastWrite
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_key, locked);
        })
        .catchError((Object e) {
          debugPrint('PresentationLockPrefs: failed to persist lock state: $e');
        });
    return _lastWrite;
  }
}
