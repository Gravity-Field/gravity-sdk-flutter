import 'package:flutter/foundation.dart';
import 'package:gravity_sdk/src/models/external/log_level.dart';
import 'package:talker/talker.dart' as talker_lib;

talker_lib.Talker get talker => LoggerManager.instance.talker;

class LoggerManager {
  LoggerManager._();

  static final LoggerManager instance = LoggerManager._();

  // One instance for the life of the process: the HTTP logger of Api holds
  // on to it from the moment the repository is built, so a later configure()
  // must retune this very instance rather than replace it.
  final talker_lib.Talker _talker = talker_lib.Talker(
    settings: talker_lib.TalkerSettings(enabled: false),
  );

  bool _isInitialized = false;

  talker_lib.Talker get talker {
    if (!_isInitialized) {
      throw StateError('Logger is not initialized.');
    }
    return _talker;
  }

  bool get isInitialized => _isInitialized;

  void initDefault() {
    _talker.configure(
      settings: talker_lib.TalkerSettings(enabled: kDebugMode),
      filter: _AcceptAllFilter(),
    );
    _isInitialized = true;
  }

  void configure(LogLevel logLevel) {
    if (logLevel == LogLevel.none) {
      _talker.configure(
        settings: talker_lib.TalkerSettings(enabled: false),
        filter: _AcceptAllFilter(),
      );
    } else {
      _talker.configure(
        settings: talker_lib.TalkerSettings(enabled: true),
        filter: _LogLevelFilter(logLevel),
      );
    }
    _isInitialized = true;
  }
}

talker_lib.LogLevel _mapToTalkerLevel(LogLevel level) {
  return switch (level) {
    LogLevel.error => talker_lib.LogLevel.error,
    LogLevel.warn => talker_lib.LogLevel.warning,
    LogLevel.info => talker_lib.LogLevel.info,
    LogLevel.debug => talker_lib.LogLevel.debug,
    LogLevel.none => talker_lib.LogLevel.verbose,
  };
}

// Talker.configure keeps the previous filter when given none, so the levels
// that need no filter pass this one explicitly.
class _AcceptAllFilter extends talker_lib.TalkerFilter {
  @override
  bool filter(talker_lib.TalkerData data) => true;
}

class _LogLevelFilter extends talker_lib.TalkerFilter {
  _LogLevelFilter(this.minLevel);

  final LogLevel minLevel;

  static const Map<talker_lib.LogLevel, int> _levelPriorities = {
    talker_lib.LogLevel.verbose: 0,
    talker_lib.LogLevel.debug: 1,
    talker_lib.LogLevel.info: 2,
    talker_lib.LogLevel.warning: 3,
    talker_lib.LogLevel.error: 4,
    talker_lib.LogLevel.critical: 5,
  };

  @override
  bool filter(talker_lib.TalkerData data) {
    final dataPriority = _levelPriorities[data.logLevel] ?? 0;
    final minPriority = _levelPriorities[_mapToTalkerLevel(minLevel)] ?? 0;

    return dataPriority >= minPriority;
  }
}
