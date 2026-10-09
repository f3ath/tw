import 'dart:async';
import 'dart:io';

import 'package:http_interop/http_interop.dart';
import 'package:http_interop_io/http_interop_io.dart';

/// Allows to start and stop an HTTP server.
class HttpServerHarness() {
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  /// starts the server
  Future<void> start(Handler handler, {String host = '0.0.0.0', int port = 8080}) async {
    if (_server != null) return;
    try {
      _server = (await HttpServer.bind(host, port))..listenInterop(handler);
    } on Exception {
      await stop();
      rethrow;
    }
  }

  /// Stops the server
  Future<void> stop({bool force = false}) async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close(force: force);
    _server = null;
  }
}
