import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/server.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/http/api_middleware.dart';
import 'package:tw_server/src/log/log.dart';

Future<void> main() async {
  group('ApiHandler', () {
    test('Uses k8s probes', () async {
      var isReady = false;
      var isLive = false;
      final h = apiMiddleware(k8sReadiness: () async => isReady, k8sLiveness: () async => isLive)(
        notFound,
      );
      await h(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 500);
      });
      await h(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 500);
      });
      isReady = true;
      await h(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 200);
      });
      await h(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 500);
      });
      isLive = true;
      await h(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 200);
      });
      await h(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
      isReady = false;
      await h(get('/k8s/readiness')).then((r) {
        expect(r.statusCode, 500);
      });
      await h(get('/k8s/liveness')).then((r) {
        expect(r.statusCode, 200);
      });
    });

    test('Handles CORS', () async {
      final h = apiMiddleware()(notFound);
      await h(options('/')).then((r) {
        expect(r.statusCode, 204);
        expect(r.headers['Access-Control-Allow-Origin'], ['*']);
        expect(r.headers['Access-Control-Allow-Methods'], [
          'POST',
          'GET',
          'DELETE',
          'PATCH',
          'OPTIONS',
        ]);
      });
    });

    test('Handles errors', () async {
      Object error = StateError('oops');
      final log = InMemoryLog();
      final h = apiMiddleware(log: log)((_) => throw error);
      await h(get('/foo')).then((r) async {
        expect(r.statusCode, 500);
        expect(
          await r.body.decodeJson(),
          equals({
            'errors': [
              {'title': 'Internal Server Error'},
            ],
          }),
        );
        expect(
          log.records.map((it) => it.message).toList(),
          equals(['Rq: get /foo', 'Error: Bad state: oops', 'Rs: 500']),
        );
        final errorRecord = log.records.where((it) => it.level == LogLevel.error).single;
        expect(errorRecord.error, error);
        expect(errorRecord.stackTrace, isNotNull);
      });

      error = UnmatchedTarget(Uri.parse('/foo'));
      await h(get('/foo')).then((r) async {
        expect(r.statusCode, 400);
        expect(
          await r.body.decodeJson(),
          equals({
            'errors': [
              {'status': '400', 'title': 'Unmatched target', 'detail': '/foo'},
            ],
          }),
        );
      });
    });
  });
}

Request get(String path) => Request('get', Uri.parse(path), Body(), Headers());

Request options(String path) => Request('options', Uri.parse(path), Body(), Headers());

Future<Response> notFound(Request _) async => Response(404, Body(), Headers());
