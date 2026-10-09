import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/application/application.dart';

import 'harness.dart';

Future<void> main() async {
  final baseUri = Uri.parse('http://localhost:8080/api/v0');

  group('Application', () {
    test('liveness and readiness probes reflect application startup', () async {
      final app = App(
        config: AppConfig(
          baseUri: baseUri,
          googleOAuthClientId: 'test-client-id',
          googleOAuthClientSecret: 'test-client-secret',
          databaseHost: 'localhost',
          databasePort: 5432,
          databaseName: 'tw_e2e',
          databaseUsername: 'tw',
          databasePassword: 'tw',
        ),
        googleOAuth: TestGoogleOAuth(),
      );

      await app(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
      await app(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 500);
      });

      await app.start();

      await app(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
      await app(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 200);
      });
    });
  });
}

Request get(String path) => Request('get', Uri.parse(path), Body(), Headers());
