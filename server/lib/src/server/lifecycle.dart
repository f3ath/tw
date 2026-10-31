class Lifecycle({
  required final Future<void> Function() _onStart,
  required final Future<void> Function() _onStop,
}) {
  Future<void>? _starting;
  Future<void>? _stopping;
  var _isRunning = false;

  Future<void> start() {
    final stopping = _stopping;
    if (stopping != null) return stopping.then((_) => start());
    if (_isRunning) return Future<void>.value();
    // Schedule the callback after installing the guard, including for reentrant calls.
    return _starting ??= Future<void>.microtask(_onStart)
        .then((_) {
          _isRunning = true;
        })
        .whenComplete(() {
          _starting = null;
        });
  }

  Future<void> stop() => _stopping ??= _stop().whenComplete(() {
    _stopping = null;
  });

  Future<void> _stop() async {
    try {
      await _starting;
    } catch (_) {
      // Startup owns rollback; there is nothing to shut down if it failed.
    }
    if (!_isRunning) return;
    await _onStop();
    // A failed shutdown retains the running state so shutdown can be retried.
    _isRunning = false;
  }
}
