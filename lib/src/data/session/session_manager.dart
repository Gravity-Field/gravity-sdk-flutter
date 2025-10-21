import 'dart:async';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/models/external/user.dart';

/// Manages user session.
/// Prevents duplicate session initialization when multiple requests happen at the same time.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  String? _userIdCache;
  String? _sessionIdCache;

  Future<void>? _sessionInitializationFuture;

  Future<User?> getUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    }

    if (_sessionInitializationFuture != null) {
      await _sessionInitializationFuture;
    }

    if (_userIdCache != null || _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }

    final userIdFromPrefs = await Prefs.instance.getUserId();
    if (userIdFromPrefs != null) {
      _userIdCache = userIdFromPrefs;
      return User(uid: userIdFromPrefs, ses: _sessionIdCache);
    }

    return null;
  }

  User? getCachedUser() {
    if (_userIdCache != null || _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }
    return null;
  }

  Future<void> saveUser(User? customUser, User? serverUser) async {
    if (customUser != null) {
      return;
    }

    final uid = serverUser?.uid;
    final ses = serverUser?.ses;

    if (uid != null) {
      await Prefs.instance.setUserId(uid);
      _userIdCache = uid;
    }

    if (ses != null) {
      _sessionIdCache = ses;
    }
  }

  Completer<void> beginSessionInitialization() {
    final completer = Completer<void>();
    _sessionInitializationFuture = completer.future;
    return completer;
  }

  void completeSessionInitialization(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
    _sessionInitializationFuture = null;
  }

  void failSessionInitialization(Completer<void> completer, Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    _sessionInitializationFuture = null;
  }

  bool get isInitializing => _sessionInitializationFuture != null;

  bool get hasSession => _userIdCache != null || _sessionIdCache != null;

  Future<void> clearSession() async {
    _userIdCache = null;
    _sessionIdCache = null;
    _sessionInitializationFuture = null;
    await Prefs.instance.clearUserId();
  }

  String? get userId => _userIdCache;

  String? get sessionId => _sessionIdCache;
}
