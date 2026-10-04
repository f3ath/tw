import 'dart:async';
import 'dart:io';

import 'package:http_interop/http_interop.dart';
import 'package:http_interop_io/http_interop_io.dart';

class JsonApiServer(
  final Handler _handler, {

  /// Server host name
  final String host = '0.0.0.0',

  /// Server port
  final int port = 8080,
}) {
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  /// starts the server
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await _createServer();
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

  Future<HttpServer> _createServer() async {
    final server = await HttpServer.bind(host, port);
    _subscription = server.listenInterop(_handler);
    return server;
  }
}
