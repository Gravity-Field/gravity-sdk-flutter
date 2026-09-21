import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _keyUserId = 'gravity_user_id';
  static const _keyDeviceId = 'gravity_device_id';
  static const _keyOutbox = 'gravity_outbox';

  Prefs._() {
    _startLoading();
  }

  /// A separate wrapper for tests: it runs its own load, so a test can give it
  /// the store its `setMockInitialValues` just installed instead of sharing
  /// the one [instance] loaded earlier in the process. Both constructors start
  /// loading right away, and neither remembers an attempt that failed.
  @visibleForTesting
  Prefs.forTesting() {
    _startLoading();
  }

  static final Prefs instance = Prefs._();

  /// The loaded store, or the attempt in flight. Only a successful attempt is
  /// kept: a first failure memoised here would disable persistence for the
  /// whole process, while the plugin itself drops its failed completer and is
  /// willing to try again.
  Future<SharedPreferences>? _pending;

  void _startLoading() {
    // The load begins with the object, not with the first read.
    unawaited(_prefs.then((_) {}, onError: (_) {}));
  }

  Future<SharedPreferences> get _prefs {
    final pending = _pending;
    if (pending != null) return pending;

    final attempt = SharedPreferences.getInstance();
    _pending = attempt;
    // Registered before any caller's await, so the next call already sees the
    // slot free; it also keeps a rejection nobody waited for from surfacing as
    // an unhandled zone error.
    unawaited(
      attempt.then((_) {}, onError: (_) {
        if (identical(_pending, attempt)) _pending = null;
      }),
    );
    return attempt;
  }

  Future<void> setUserId(String uid) async {
    await _writeIdentity(_keyUserId, uid);
  }

  Future<String?> getUserId() async {
    return _readStringValue(_keyUserId);
  }

  Future<void> removeUserId() async {
    await _removeIdentity(_keyUserId);
  }

  /// Best effort, unlike the uid: no public call promises the device id is
  /// stored, and every request needs one. On a refused write the plugin's
  /// cache keeps the id, so this process goes on with it; the next launch
  /// mints another.
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

  /// Identity keys back a promise the public API makes — resetUser() claims
  /// the uid is gone, restoreUserId() that it is stored — so a refused write
  /// is retried once and then told to the caller. The outbox has its own
  /// retry machinery and is deliberately not routed through here.
  Future<void> _writeIdentity(String key, String value) async {
    if (await _setStringValue(key, value)) return;
    if (await _setStringValue(key, value)) return;
    throw StateError('SharedPreferences rejected the write of $key');
  }

  Future<void> _removeIdentity(String key) async {
    if (await _removeValue(key)) return;
    if (await _removeValue(key)) return;
    throw StateError('SharedPreferences rejected the removal of $key');
  }

  Future<bool> _setStringValue(String key, String value) async {
    final prefs = await _prefs;
    return prefs.setString(key, value);
  }

  Future<bool> _removeValue(String key) async {
    final prefs = await _prefs;
    return prefs.remove(key);
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
