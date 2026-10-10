import 'dart:io';

import 'package:tw_server/src/log/log.dart';

class StdErrLog({final LogLevel minLevel = LogLevel.trace, StringSink? sink}) implements Log {
  this : _sink = sink ?? stderr;

  final StringSink _sink;

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
