import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_interop/http_interop.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/app/app.dart';
import 'package:tw_server/src/app/app_config.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/db/connection_from_config.dart';
import 'package:tw_server/src/http/http_server_harness.dart';
import 'package:tw_server/src/log/sink_log.dart';
import 'package:tw_server/tw_server.dart';

final testConfig = AppConfig(
  baseUri: Uri(path: '/api/v0'),
  googleOAuthClientId: 'test-client-id',
  googleOAuthClientSecret: 'test-client-secret',
  databaseHost: 'localhost',
  databasePort: 5432,
  databaseName: 'tw_e2e',
  databaseUsername: 'tw',
  databasePassword: 'tw',
);

Future<TestApplication> startTestApplication() async {
  await resetDatabaseSchema(testConfig);
  final googleOAuth = TestGoogleOAuth();
  final app = App(testConfig, googleOAuth: googleOAuth, log: SinkLog(stderr));
  await app.start();

  final server = HttpServerHarness();
  await server.start(app.call, host: 'localhost', port: 0);
  final baseUri = Uri(
    scheme: 'http',
    host: 'localhost',
    port: server.port,
    path: testConfig.baseUri.path,
  );
  final urlDesign = StandardUriDesign(baseUri);
  final clientHandler = oneOffHttpHandler;
  return TestApplication(
    server: server,
    baseUri: baseUri,
    urlDesign: urlDesign,
    clientHandler: clientHandler,
    googleOAuth: googleOAuth,
    client: TwApiClient(urlDesign, clientHandler),
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

class TestApplication({
  required final HttpServerHarness server,
  required final Uri baseUri,
  required final UriDesign urlDesign,
  required final Handler clientHandler,
  required final TestGoogleOAuth googleOAuth,
  required final TwApiClient client,
}) {
  Future<Response> googleCallback(String code, {String? state}) => clientHandler(
    Request(
      'get',
      baseUri.replace(
        path: '/auth/google/callback',
        queryParameters: {'code': code, 'state': state ?? googleOAuth.states.last},
      ),
      Body(),
      Headers(),
    ),
  );

  Future<void> stop() => server.stop(force: true);
}

Future<void> resetDatabaseSchema(AppConfig config) async {
  await withTestDatabase(config, (connection) async {
    await connection.execute(
      Sql.named('''
DROP SCHEMA IF EXISTS public CASCADE
'''),
    );
    await connection.execute(
      Sql.named('''
CREATE SCHEMA IF NOT EXISTS public
'''),
    );
  });
}

Future<T> withTestDatabase<T>(
  AppConfig config,
  Future<T> Function(Connection connection) callback,
) async {
  final connection = await connectionFromConfig(config);
  try {
    return await callback(connection);
  } finally {
    await connection.close();
  }
}

class TestGoogleOAuth({var String email = 'user@example.com', var String name = 'Test User'})
    implements GoogleOAuth {
  Uri? _authorizationUri;

  Uri get authorizationUri => _authorizationUri!;
  final states = <String>[];
  Map<String, String>? queryParameters;

  @override
  Uri startAuthorization(String state) {
    states.add(state);
    return _authorizationUri = Uri.https('accounts.google.com', '/o/oauth2/auth', {'state': state});
  }

  @override
  Future<GoogleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    this.queryParameters = queryParameters;
    return GoogleOAuthSession(email: email, name: name);
  }
}
