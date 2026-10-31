import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:server/src/server/server.dart';

import 'harness.dart';

Future<void> main() async {
  group('k8s probes', () {
    setUp(() async {
      await resetDatabaseSchema(testConfig);
    });

    test('liveness and readiness probes reflect server startup', () async {
      final testServer = Server(testConfig);
      addTearDown(testServer.stop);

      await testServer(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
      await testServer(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 500);
      });

      await testServer.start();

      await testServer(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
      await testServer(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 200);
      });
    });
  });
}

Request get(String path) => Request('GET', Uri.parse(path), Body.empty(), Headers());
