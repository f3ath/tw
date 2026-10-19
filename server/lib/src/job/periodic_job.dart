import 'dart:async';

import 'package:server/src/log/log.dart';

class PeriodicJob(
  final Future<void> Function() _task, {
  required final Duration interval,
  final Log log = const NoLog(),
}) {
  Timer? _timer;
  Future<void>? _running;

  void start() {
    _timer ??= Timer.periodic(interval, (_) {
      _running ??= _run().whenComplete(() {
        _running = null;
      });
    });
  }

  Future<void> _run() async {
    try {
      await _task();
    } catch (error, stackTrace) {
      log.error('Periodic job failed.', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _running;
  }
}
