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

  int _generation = 0;
  int get generation => _generation;

  Future<User?> getUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    }

    if (_sessionInitializationFuture != null) {
      await _sessionInitializationFuture;
    }

    if (_userIdCache != null && _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }

    final userIdFromPrefs = await Prefs.instance.getUserId();
    return User(uid: userIdFromPrefs, ses: _sessionIdCache);
  }

  User? getCachedUser() {
    if (_userIdCache != null || _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }
    return null;
  }

  Future<void> saveUser(User? customUser, User? serverUser, int capturedGeneration) async {
    if (capturedGeneration != _generation) {
      return;
    }
    if (customUser != null) {
      return;
    }

    final uid = serverUser?.uid;
    final ses = serverUser?.ses;

    if (uid != null && uid != _userIdCache) {
      await Prefs.instance.setUserId(uid);
      if (capturedGeneration != _generation) {
        await Prefs.instance.removeUserId();
        return;
      }
      _userIdCache = uid;
    }

    if (ses != null) {
      _sessionIdCache = ses;
    }
  }

  Future<void> resetSession() async {
    _generation++;
    _userIdCache = null;
    _sessionIdCache = null;
    final resetCompleter = Completer<void>();
    _sessionInitializationFuture = resetCompleter.future;
    try {
      await Prefs.instance.removeUserId();
    } finally {
      if (identical(_sessionInitializationFuture, resetCompleter.future)) {
        _sessionInitializationFuture = null;
      }
      resetCompleter.complete();
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
    if (identical(_sessionInitializationFuture, completer.future)) {
      _sessionInitializationFuture = null;
    }
  }

  void failSessionInitialization(Completer<void> completer, Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    if (identical(_sessionInitializationFuture, completer.future)) {
      _sessionInitializationFuture = null;
    }
  }

  bool get isInitializing => _sessionInitializationFuture != null;

  bool get hasSession => _userIdCache != null || _sessionIdCache != null;

  String? get userId => _userIdCache;

  String? get sessionId => _sessionIdCache;
}
