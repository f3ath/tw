import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:server/src/server/server.dart';
import 'package:server/src/server/server_config.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class TestHarness() {
  final _config = ServerConfig(
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
    instanceType: 'test',
  );

  late final Server _server = Server(_config);

  Future<void> startServer() => _server.start();

  Future<void> stopServer() => _server.stop();

  TwApiClient newClient() => TwApiClient(StandardUriDesign(_config.baseUri), _server.handler);

  Future<TwApiClient> login({String? email, String? name}) async {
    final client = newClient();
    email ??= '${const Uuid().v4()}@example.com';
    name ??= 'Test User ${const Uuid().v4()}';
    final session = await client.createSession();
    expect(session, isNotNull);
    expect(await client.fetchCurrentUser(), isNull);
    final redirect = session.completionUri!;
    final response = await _server.handler(
      Request(
        'GET',
        Uri(
          path: '/auth/google/callback',
          queryParameters: {
            'nonce': redirect.queryParameters['nonce']!,
            'email': email,
            'name': name,
          },
        ),
        Body.empty(),
        Headers(),
      ),
    );
    expect(response.statusCode, 200);
    return client;
  }
}

Matcher throwsStatusCode(int expected) => throwsA(
  isA<RequestFailure>().having(
    (failure) => failure.rawResponse.httpResponse.statusCode,
    'status code',
    expected,
  ),
);
