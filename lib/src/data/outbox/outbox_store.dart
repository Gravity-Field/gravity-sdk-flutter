import 'dart:convert';

import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';

/// FIFO persistence for [OutboxEntry] on top of SharedPreferences.
///
/// The whole queue lives under one key as a JSON array. It is read once,
/// kept in memory and written through after every mutation; writes are
/// serialised so a slow write can never overwrite a newer state. Every
/// mutation awaits [load] first, so it can never persist over a queue that
/// has not been read yet.
class OutboxStore {
  OutboxStore({Prefs? prefs}) : _prefs = prefs ?? Prefs.instance;

  final Prefs _prefs;
  final List<OutboxEntry> _entries = [];
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  /// Memory is ahead of the disk: a write failed after a mutation that must
  /// not be rolled back (a delivered entry was removed). [sync] retries it.
  bool _dirty = false;

  /// Reads the queue once; concurrent and repeated calls share one read.
  /// A failed read is not memoised: the error reaches the caller and the
  /// next call tries again.
  Future<void> load() {
    return _loading ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final raw = await _prefs.getOutbox();
      if (raw == null) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return;
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final entry = OutboxEntry.fromJson(item);
          if (entry != null) _entries.add(entry);
        }
      } on FormatException {
        // Unreadable queue: start over rather than fail every send.
        _entries.clear();
      }
    } catch (_) {
      // Storage itself is unavailable: forget the memoised attempt so the
      // caller can retry later, and let the error through.
      _entries.clear();
      _loading = null;
      rethrow;
    }
  }

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  OutboxEntry? get head => _entries.isEmpty ? null : _entries.first;

  List<OutboxEntry> snapshot() => List.unmodifiable(_entries);

  /// Appends [entry]; when the queue exceeds [maxEntries] the oldest entries
  /// are dropped and returned. A [maxEntries] below 1 is treated as 1, so an
  /// invalid setting never drops the entry that was just appended.
  ///
  /// Not on disk means not queued: a failed write rolls the append back, so a
  /// drain never sends an entry its caller still owns.
  Future<List<OutboxEntry>> append(OutboxEntry entry, {required int maxEntries}) async {
    await load();
    final limit = maxEntries < 1 ? 1 : maxEntries;
    final dropped = await _transaction(() {
      _entries.add(entry);
      final dropped = <OutboxEntry>[];
      while (_entries.length > limit) {
        dropped.add(_entries.removeAt(0));
      }
      return dropped;
    }, rollbackOnFailure: true);
    return dropped ?? const [];
  }

  /// Drops the oldest entries beyond [maxEntries] and returns them; applies a
  /// lowered limit to what was loaded from disk.
  Future<List<OutboxEntry>> pruneOverflow({required int maxEntries}) async {
    await load();
    final limit = maxEntries < 1 ? 1 : maxEntries;
    final dropped = await _transaction(() {
      if (_entries.length <= limit) return null;
      final dropped = _entries.sublist(0, _entries.length - limit);
      _entries.removeRange(0, dropped.length);
      return dropped;
    });
    return dropped ?? const [];
  }

  Future<void> removeById(String id) async {
    await load();
    await _transaction(() {
      final before = _entries.length;
      _entries.removeWhere((e) => e.id == id);
      return _entries.length == before ? null : true;
    });
  }

  /// Writes [entry] over the queued entry with the same id; a no-op when the
  /// entry is already gone.
  Future<void> replace(OutboxEntry entry) async {
    await load();
    await _transaction(() {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index == -1) return null;
      _entries[index] = entry;
      return true;
    });
  }

  /// Drops entries whose [OutboxEntry.createdAt] is older than [maxAge]
  /// relative to [now] and returns them.
  Future<List<OutboxEntry>> pruneExpired({required Duration maxAge, required DateTime now}) async {
    await load();
    final dropped = await _transaction(() {
      final dropped = _entries.where((e) => now.difference(e.createdAt) > maxAge).toList();
      if (dropped.isEmpty) return null;
      _entries.removeWhere(dropped.contains);
      return dropped;
    });
    return dropped ?? const [];
  }

  /// Drops every entry. Wipes the disk even when the queue could not be
  /// read: an unreadable queue is still data the caller asked to remove.
  Future<void> clear() async {
    try {
      await load();
    } catch (_) {
      // Fall through: the write below replaces whatever is on disk.
    }
    await _transaction(() {
      _entries.clear();
      return true;
    });
  }

  /// Re-writes the queue if an earlier write failed after a removal, so a
  /// delivered entry does not come back from disk on the next launch.
  Future<void> sync() async {
    await load();
    if (!_dirty) return;
    await _transaction(() => true);
  }

  /// Runs [mutate] and writes the result, serialised with every other
  /// mutation so a snapshot can never include or roll back someone else's
  /// change. [mutate] returns `null` to signal "nothing changed" and skip the
  /// write. On a failed write the memory is rolled back when
  /// [rollbackOnFailure] is set, otherwise it stays ahead of the disk and is
  /// re-written by [sync].
  Future<T?> _transaction<T>(T? Function() mutate, {bool rollbackOnFailure = false}) {
    final run = _writes.then((_) async {
      final before = rollbackOnFailure ? List.of(_entries) : null;
      final result = mutate();
      if (result == null) return null;
      try {
        await _prefs.setOutbox(jsonEncode(_entries.map((e) => e.toJson()).toList()));
        _dirty = false;
      } catch (_) {
        if (before != null) {
          _entries
            ..clear()
            ..addAll(before);
        } else {
          _dirty = true;
        }
        rethrow;
      }
      return result;
    });
    // The chain must survive a failed write, so it keeps only the completion.
    _writes = run.then((_) {}, onError: (_) {});
    return run;
  }
}
