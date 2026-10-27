import 'dart:io';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:postgres/postgres.dart';
import 'package:server/src/app/app.dart';
import 'package:server/src/app/app_config.dart';
import 'package:server/src/auth/simple_oauth.dart';
import 'package:server/src/db/connection_from_config.dart';
import 'package:server/src/log/sink_log.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';

Matcher statusCode(int expected) => throwsA(
  isA<RequestFailure>().having(
    (r) => r.rawResponse.httpResponse.statusCode,
    'Status Code',
    equals(expected),
  ),
);

final testConfig = createTestConfig();

AppConfig createTestConfig({
  Duration sessionCleanupInterval = const Duration(minutes: 1),
  Duration pendingSessionMaxAge = const Duration(minutes: 15),
}) => AppConfig(
  baseUri: Uri(path: '/api/v0'),
  googleOAuthClientId: 'test-client-id',
  googleOAuthClientSecret: 'test-client-secret',
  databaseHost: 'localhost',
  databasePort: 5432,
  databaseName: 'tw_e2e',
  databaseSystemUsername: 'tw_system',
  databaseSystemPassword: 'tw_system',
  databaseTenantUsername: 'tw_tenant',
  databaseTenantPassword: 'tw_tenant',
  sessionCleanupInterval: sessionCleanupInterval,
  pendingSessionMaxAge: pendingSessionMaxAge,
);

Future<TestApplication> startTestApplication() async {
  await resetDatabaseSchema(testConfig);
  final googleOAuth = TestGoogleOAuth();
  final app = App(testConfig, oauth: googleOAuth, log: SinkLog(stderr));
  await app.start();

  final urlDesign = StandardUriDesign(testConfig.baseUri);
  return TestApplication(
    application: app,
    baseUri: testConfig.baseUri,
    urlDesign: urlDesign,
    clientHandler: app.call,
    googleOAuth: googleOAuth,
    client: TwApiClient(urlDesign, app.call),
  );
}

class TestApplication({
  required final App application,
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
      Body.empty(),
      Headers(),
    ),
  );

  Future<void> stop() => application.stop();
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
  final connection = await SystemConnection.fromConfig(config);
  try {
    return await callback(connection);
  } finally {
    await connection.close();
  }
}

class TestGoogleOAuth({var String email = 'user@example.com', var String name = 'Test User'})
    implements SimpleOAuth {
  Uri? _authorizationUri;

  Uri get authorizationUri => _authorizationUri!;
  final states = <String>[];
  Map<String, String>? queryParameters;

  @override
  Uri startAuthorization(String nonce) {
    states.add(nonce);
    return _authorizationUri = Uri.https('accounts.google.com', '/o/oauth2/auth', {'state': nonce});
  }

  @override
  Future<SimpleOAuthSession?> finishAuthorization(Map<String, String> queryParameters) async {
    this.queryParameters = queryParameters;
    return SimpleOAuthSession(email: email, name: name, nonce: queryParameters['state'] as String);
  }
}
