import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/application/app.dart';

import 'harness.dart';

Future<void> main() async {
  group('Application', () {
    setUp(() async {
      await resetDatabaseSchema(testConfig);
    });

    test('liveness and readiness probes reflect application startup', () async {
      final app = App(config: testConfig, googleOAuth: TestGoogleOAuth());

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
