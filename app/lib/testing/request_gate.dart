import 'dart:async';

class RequestGate {
  Future<void>? _next;

  Completer<void> pause() {
    final completer = Completer<void>();
    _next = completer.future;
    return completer;
  }

  Future<void> wait() async {
    final pending = _next;
    _next = null;
    await pending;
  }
}
