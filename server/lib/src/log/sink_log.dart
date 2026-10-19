import 'package:server/src/log/log.dart';

class SinkLog(final StringSink _sink, {final LogLevel minLevel = LogLevel.trace}) implements Log {
  @override
  void log(
    LogLevel level,
    Object? message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.level > minLevel.level) return;

    final timestamp = (time ?? DateTime.now()).toIso8601String();
    _sink.writeln('$timestamp ${level.name.toUpperCase()} $message');
    if (error != null) _sink.writeln(error);
    if (stackTrace != null) _sink.writeln(stackTrace);
  }
}
