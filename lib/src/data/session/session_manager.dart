import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/models/external/user.dart';

/// Manages user session.
/// Prevents duplicate session initialization when multiple requests happen at the same time.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  /// Runs inside the serialized uid write queue right before the uid reaches
  /// Prefs; tests use it to hold a write in flight.
  @visibleForTesting
  static Future<void> Function(String uid)? beforeUserIdWrite;

  String? _userIdCache;
  String? _sessionIdCache;

  Future<void>? _sessionInitializationFuture;

  int _generation = 0;
  int get generation => _generation;

  /// Completes and is replaced on every generation bump, so a waiter parked
  /// behind an older gate can move on without waiting for that gate's owner.
  Completer<void> _generationChanged = Completer<void>();

  void _bumpGeneration() {
    _generation++;
    final changed = _generationChanged;
    _generationChanged = Completer<void>();
    changed.complete();
  }

  /// Called (in a microtask) when the stored server uid becomes known to this
  /// process or changes: after the first successful request of a cold start,
  /// after [resetSession] (with null) and after [restoreUserId]. Reading the
  /// uid is not a change; neither is a server answer echoing the current one.
  void Function(String? uid)? onUserIdChanged;

  /// The last uid handed to [onUserIdChanged]; compared and updated only at
  /// the point of a successful write, inside the write queue, so concurrent
  /// writes of one uid cannot report it twice.
  String? _notifiedUid;

  Future<User?> getUser(User? customUser) async {
    if (customUser != null) {
      return customUser;
    }

    await _awaitSessionGate();

    if (_userIdCache != null && _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }

    final userIdFromPrefs = await Prefs.instance.getUserId();
    return User(uid: userIdFromPrefs, ses: _sessionIdCache);
  }

  /// The server-assigned uid of the anonymous session, waiting for an
  /// initialization in flight. Null until the server has assigned one.
  Future<String?> loadUserId() async => (await getUser(null))?.uid;

  /// Parks behind the current gate until none is stored. A reset or restore
  /// bumps the generation and replaces the gate: the waiter is released at
  /// once (without waiting for the old owner's network round trip) and parks
  /// behind whatever gate is stored then (the replacing write may still hold
  /// its own). An old gate failing later says nothing about the current
  /// session: its error is dropped. A failure of the current generation is
  /// rethrown.
  Future<void> _awaitSessionGate() async {
    while (true) {
      final gate = _sessionInitializationFuture;
      if (gate == null) {
        return;
      }
      final capturedGeneration = _generation;
      try {
        // Future.any keeps listening to the loser, so an old gate's late
        // error never surfaces as an unhandled zone error.
        await Future.any([gate, _generationChanged.future]);
      } catch (_) {
        if (capturedGeneration == _generation) {
          rethrow;
        }
      }
    }
  }

  User? getCachedUser() {
    if (_userIdCache != null || _sessionIdCache != null) {
      return User(uid: _userIdCache, ses: _sessionIdCache);
    }
    return null;
  }

  // Serializes uid writes: the awaits inside Prefs are suspension points
  // where a stale cleanup could otherwise erase a newer generation's uid.
  Future<void> _userIdWrites = Future<void>.value();

  Future<void> _enqueueUserIdWrite(Future<void> Function() op) {
    final run = _userIdWrites.then((_) => op());
    // Callers observe errors through `run`; the chain itself must survive.
    _userIdWrites = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _writeUserId(String uid) async {
    final hook = beforeUserIdWrite;
    if (hook != null) {
      await hook(uid);
    }
    await Prefs.instance.setUserId(uid);
  }

  /// Records [uid] as the one the listener knows and notifies it if that is a
  /// change. Called only from inside the write queue, after the write landed.
  void _noteUserId(String? uid) {
    if (uid == _notifiedUid) {
      return;
    }
    _notifiedUid = uid;
    final listener = onUserIdChanged;
    if (listener != null) {
      // Off the write chain: a throwing listener must not break later writes.
      scheduleMicrotask(() => listener(uid));
    }
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
      await _enqueueUserIdWrite(() async {
        if (capturedGeneration != _generation) {
          return;
        }
        await _writeUserId(uid);
        if (capturedGeneration != _generation) {
          // A reset landed during our write; undo it. Writes are serialized,
          // so this cannot hit foreign data.
          if (await Prefs.instance.getUserId() == uid) {
            await Prefs.instance.removeUserId();
          }
          return;
        }
        _userIdCache = uid;
        _noteUserId(uid);
      });
    }

    if (ses != null && capturedGeneration == _generation) {
      _sessionIdCache = ses;
    }
  }

  Future<void> resetSession() async {
    _bumpGeneration();
    _userIdCache = null;
    _sessionIdCache = null;
    final resetCompleter = Completer<void>();
    _sessionInitializationFuture = resetCompleter.future;
    try {
      await _enqueueUserIdWrite(() async {
        // A uid left by a previous launch that nobody reported yet is still
        // a uid the app may hold a copy of: removing it is a change to tell.
        final stored = await Prefs.instance.getUserId();
        await Prefs.instance.removeUserId();
        if (stored != null) {
          _notifiedUid ??= stored;
        }
        _noteUserId(null);
      });
    } finally {
      if (identical(_sessionInitializationFuture, resetCompleter.future)) {
        _sessionInitializationFuture = null;
      }
      resetCompleter.complete();
    }
  }

  /// Makes [uid] the stored uid without a session, as if the app had started
  /// with it on disk: the next session request carries it and the server
  /// restores that user (or, for an unknown uid, assigns a new one).
  ///
  /// Like [resetSession] it opens a new generation and holds the gate for the
  /// duration of the write. The uid cache is filled only after the write, so
  /// readers released by the gate see the stored value.
  Future<void> restoreUserId(String uid) async {
    _bumpGeneration();
    final capturedGeneration = _generation;
    _userIdCache = null;
    _sessionIdCache = null;
    final restoreCompleter = Completer<void>();
    _sessionInitializationFuture = restoreCompleter.future;
    try {
      await _enqueueUserIdWrite(() async {
        await _writeUserId(uid);
        if (capturedGeneration != _generation) {
          // A newer reset or restore is queued behind us and will overwrite
          // the stored uid; its generation owns the cache now.
          return;
        }
        _userIdCache = uid;
        _noteUserId(uid);
      });
    } finally {
      if (identical(_sessionInitializationFuture, restoreCompleter.future)) {
        _sessionInitializationFuture = null;
      }
      restoreCompleter.complete();
    }
  }

  Completer<void> beginSessionInitialization() {
    final completer = Completer<void>();
    // The stored future may have no awaiter when it error-completes, which
    // would leak an unhandled Zone error; real getUser awaiters attach their
    // own listeners and still observe it.
    unawaited(completer.future.catchError((_) {}));
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

  /// A session exists once the server has answered. A restored uid alone is
  /// not a session: the next request must still open one.
  bool get hasSession => _sessionIdCache != null;

  String? get userId => _userIdCache;

  String? get sessionId => _sessionIdCache;
}
