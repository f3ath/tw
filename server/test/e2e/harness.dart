import 'package:http/http.dart' as http;
import 'package:http_interop/http_interop.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:server/src/http/http_server_harness.dart';
import 'package:shared/api.dart';

import '../app/harness.dart' as app_test;
import '../app/harness.dart' hide startTestApplication;

export '../app/harness.dart' hide startTestApplication;

Future<TestApplication> startTestApplication() async {
  final app = await app_test.startTestApplication();
  final server = HttpServerHarness();
  try {
    await server.start(app.application.call, host: 'localhost', port: 0);
  } catch (_) {
    await app.stop();
    rethrow;
  }
  final baseUri = Uri(scheme: 'http', host: 'localhost', port: server.port, path: app.baseUri.path);
  final urlDesign = StandardUriDesign(baseUri);
  return HttpTestApplication(
    server,
    application: app.application,
    baseUri: baseUri,
    urlDesign: urlDesign,
    clientHandler: oneOffHttpHandler,
    googleOAuth: app.googleOAuth,
    client: TwApiClient(urlDesign, oneOffHttpHandler),
  );
}

Future<Response> oneOffHttpHandler(Request request) async {
  final client = http.Client();
  try {
    return await client.handleInterop(request);
  } finally {
    client.close();
  }
}

class HttpTestApplication(
  final HttpServerHarness server, {
  required super.application,
  required super.baseUri,
  required super.urlDesign,
  required super.clientHandler,
  required super.googleOAuth,
  required super.client,
}) extends TestApplication {
  @override
  Future<void> stop() async {
    try {
      await server.stop(force: true);
    } finally {
      await super.stop();
    }
  }
}
