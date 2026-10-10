import 'package:http_interop/http_interop.dart';
import 'package:postgres/postgres.dart';
import 'package:tw_server/src/application/app_config.dart';
import 'package:tw_server/src/application/app.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';

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

Future<UserRecord?> fetchUserByEmail(AppConfig config, String email) =>
    withTestDatabase(config, (connection) => UsersDAO(connection).fetchByEmail(email));

Future<SessionRecord?> fetchSession(AppConfig config, String id) =>
    withTestDatabase(config, (connection) => SessionsDAO(connection).fetch(id));

Future<SessionRecord?> fetchSessionByKey(AppConfig config, String sessionKey) =>
    withTestDatabase(config, (connection) => SessionsDAO(connection).fetchBySessionKey(sessionKey));

class TestGoogleOAuth({
  var String email = 'user@example.com',
  var String name = 'Test User',
  var String sessionId = 'test-session-id',
}) implements GoogleOAuth {
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
    return GoogleOAuthSession(id: sessionId, email: email, name: name);
  }
}
