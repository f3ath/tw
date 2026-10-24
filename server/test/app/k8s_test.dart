import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:server/src/app/app.dart';

import 'harness.dart';

Future<void> main() async {
  group('k8s probes', () {
    setUp(() async {
      await resetDatabaseSchema(testConfig);
    });

    test('liveness and readiness probes reflect application startup', () async {
      final app = App(testConfig, googleOAuth: TestGoogleOAuth());
      addTearDown(app.stop);

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

Request get(String path) => Request('get', Uri.parse(path), Body.empty(), Headers());
