import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _keyUserId = 'gravity_user_id';
  static const _keyDeviceId = 'gravity_device_id';
  static const _keyOutbox = 'gravity_outbox';

  Prefs._();

  /// A separate wrapper for tests: it calls `SharedPreferences.getInstance()`
  /// on construction, while [instance] is a lazy singleton that keeps the
  /// future it captured on first access — one that may have been taken before
  /// a test's `setMockInitialValues`.
  @visibleForTesting
  Prefs.forTesting();

  static final Prefs instance = Prefs._();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> setUserId(String uid) async {
    await _setStringValue(_keyUserId, uid);
  }

  Future<String?> getUserId() async {
    return _readStringValue(_keyUserId);
  }

  Future<void> removeUserId() async {
    final prefs = await _prefs;
    await prefs.remove(_keyUserId);
  }

  Future<void> setDeviceId(String deviceId) async {
    await _setStringValue(_keyDeviceId, deviceId);
  }

  Future<String?> getDeviceId() async {
    return _readStringValue(_keyDeviceId);
  }

  Future<String?> getOutbox() async {
    return _readStringValue(_keyOutbox);
  }

  /// Throws when the platform refused the write (Android reports the result
  /// of `commit()`): the in-memory copy would then differ from the disk.
  Future<void> setOutbox(String json) async {
    final written = await _setStringValue(_keyOutbox, json);
    if (!written) throw StateError('SharedPreferences rejected the outbox write');
  }

  Future<void> removeOutbox() async {
    final prefs = await _prefs;
    await prefs.remove(_keyOutbox);
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
