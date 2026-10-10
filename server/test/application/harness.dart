import 'package:http_interop/http_interop.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/application/app_config.dart';
import 'package:tw_server/src/application/app.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';

final testConfig = AppConfig(
  baseUri: Uri.parse('http://localhost:8080/api/v0'),
  googleOAuthClientId: 'test-client-id',
  googleOAuthClientSecret: 'test-client-secret',
  databaseHost: 'localhost',
  databasePort: 5432,
  databaseName: 'tw_e2e',
  databaseUsername: 'tw',
  databasePassword: 'tw',
);

Future<Handler> testApplicationHandler(AppConfig config, GoogleOAuth googleOAuth) async {
  final app = App(config: config, googleOAuth: googleOAuth);
  await app.start();
  return app.call;
}

Future<void> resetDatabaseSchema(AppConfig config) async {
  await withTestDatabase(config, (connection) async {
    await connection.execute(Sql.named('DROP SCHEMA IF EXISTS public CASCADE'));
    await connection.execute(Sql.named('CREATE SCHEMA IF NOT EXISTS public'));
  });
}

Future<T> withTestDatabase<T>(
  AppConfig config,
  Future<T> Function(Connection connection) callback,
) async {
  final connection = await Connection.open(
    Endpoint(
      host: config.databaseHost,
      port: config.databasePort,
      database: config.databaseName,
      username: config.databaseUsername,
      password: config.databasePassword,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
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
