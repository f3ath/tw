import 'package:http/http.dart' as http;
import 'package:http_interop/http_interop.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:server/src/http/http_server_harness.dart';
import 'package:shared/api.dart';

import '../server/harness.dart' as server_test;
import '../server/harness.dart' hide startTestServer;

export '../server/harness.dart' hide startTestServer;

Future<TestServer> startTestServer() async {
  final testServer = await server_test.startTestServer();
  final httpServer = HttpServerHarness();
  try {
    await httpServer.start(testServer.server.call, host: 'localhost', port: 0);
  } catch (_) {
    await testServer.stop();
    rethrow;
  }
  final baseUri = Uri(
    scheme: 'http',
    host: 'localhost',
    port: httpServer.port,
    path: testServer.baseUri.path,
  );
  final urlDesign = StandardUriDesign(baseUri);
  return HttpTestServer(
    httpServer,
    server: testServer.server,
    baseUri: baseUri,
    urlDesign: urlDesign,
    clientHandler: oneOffHttpHandler,
    googleOAuth: testServer.googleOAuth,
    client: TwApiClient(urlDesign, oneOffHttpHandler),
  );
}

Future<Response> oneOffHttpHandler(Request request) async {
  final client = http.Client();
  try {
    return await client.sendInterop(request);
  } finally {
    client.close();
  }
}

class HttpTestServer(
  final HttpServerHarness httpServer, {
  required super.server,
  required super.baseUri,
  required super.urlDesign,
  required super.clientHandler,
  required super.googleOAuth,
  required super.client,
}) extends TestServer {
  @override
  Future<void> stop() async {
    try {
      await httpServer.stop(force: true);
    } finally {
      await super.stop();
    }
  }
}
