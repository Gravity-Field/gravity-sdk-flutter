import 'package:shared_preferences/shared_preferences.dart';


class Prefs {
  static const _keyUserId = 'gravity_user_id';

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> setUserId(String uid) async {
    await _setStringValue(_keyUserId, uid);
  }

  Future<String?> getUserId() async {
    return _readStringValue(_keyUserId);
  }

  Future<bool> _setStringValue(String key, String value) async {
    final prefs = await _prefs;
    return prefs.setString(key, value);
  }

  Future<String?> _readStringValue(String key) async {
    final prefs = await _prefs;
    if (prefs.containsKey(key)) {
      return prefs.getString(key);
    } else {
      return null;
    }
  }
}
