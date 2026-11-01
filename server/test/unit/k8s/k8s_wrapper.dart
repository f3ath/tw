import 'package:http_interop/http_interop.dart';
import 'package:server/src/k8s/container_probes.dart';
import 'package:test/test.dart';

void main() {
  for (final probe in ['started', 'ready', 'live']) {
    test('$probe reports its current state without calling the wrapped handler', () async {
      final states = <String, bool>{};
      final handler = containerProbesMiddleware(_TestProbes(states), (_) async {
        fail('Probe requests must not reach the wrapped handler');
      });
      final request = Request('GET', Uri(path: '/k8s/is-$probe'), Body.empty(), Headers());

      expect((await handler(request)).statusCode, 500);
      states[probe] = true;
      expect((await handler(request)).statusCode, 200);
      states[probe] = false;
      expect((await handler(request)).statusCode, 500);
    });
  }

  test('unmatched paths forward the original request and return the wrapped response', () async {
    final response = Response(202, Body.empty(), Headers());
    final requests = <Request>[];
    final handler = containerProbesMiddleware(_TestProbes({}), (request) async {
      requests.add(request);
      return response;
    });

    for (final path in ['/api/v0/sessions', '/k8s/unknown', '/k8s/is-live/']) {
      final request = Request('GET', Uri(path: path), Body.empty(), Headers());
      expect(await handler(request), same(response));
      expect(requests.last, same(request));
    }
    expect(requests, hasLength(3));
  });
}

class _TestProbes(final Map<String, bool> _states) implements ContainerProbes {
  @override
  bool isLive() => _states['live'] ?? false;

  @override
  bool isReady() => _states['ready'] ?? false;

  @override
  bool isStarted() => _states['started'] ?? false;
}
