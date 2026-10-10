enum LogLevel(final int level) {
  trace(600),
  debug(500),
  info(400),
  warning(300),
  error(200),
  fatal(100),
}

abstract interface class Log() {
  void log(
    LogLevel level,
    Object? message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  });
}

extension LogExt on Log {
  void trace(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.trace, message, time: time, error: error, stackTrace: stackTrace);

  void debug(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.debug, message, time: time, error: error, stackTrace: stackTrace);

  void info(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.info, message, time: time, error: error, stackTrace: stackTrace);

  void warning(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warning, message, time: time, error: error, stackTrace: stackTrace);

  void error(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, time: time, error: error, stackTrace: stackTrace);

  void fatal(Object? message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.fatal, message, time: time, error: error, stackTrace: stackTrace);
}

class const NoLog() implements Log {
  @override
  void log(
    LogLevel level,
    Object? message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

class LogRecord(
  final LogLevel level,
  final Object? message, {
  final DateTime? time,
  final Object? error,
  final StackTrace? stackTrace,
}) {}

class InMemoryLog() implements Log {
  final records = <LogRecord>[];

  @override
  void log(
    LogLevel level,
    Object? message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    records.add(LogRecord(level, message, time: time, error: error, stackTrace: stackTrace));
  }
}
