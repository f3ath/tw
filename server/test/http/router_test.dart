import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/http/routing_handler.dart' as http_router;

Request request(String uri, {String method = 'GET'}) =>
    Request(method, Uri.parse(uri), Body(), Headers());

Response response(int status) => Response(status, Body(), Headers());

void main() {
  group('router', () {
    test('evaluates routes in order and stops after the first match', () async {
      final visited = <String>[];
      final input = request('/hello');
      final expected = response(200);
      final handler = http_router.routingHandler([
        (
          (_) {
            visited.add('miss');
            return false;
          },
          (_) async => fail('A non-matching handler must not run'),
        ),
        (
          (_) {
            visited.add('match');
            return true;
          },
          (actual) async {
            expect(actual, same(input));
            return expected;
          },
        ),
        (
          (_) => fail('Later routes must not be evaluated'),
          (_) async => fail('Later handlers must not run'),
        ),
      ], (_) async => fail('Default handler must not run'));

      expect(await handler(input), same(expected));
      expect(visited, ['miss', 'match']);
    });

    test('forwards unmatched requests to the default handler', () async {
      final input = request('/missing');
      final expected = response(202);
      var calls = 0;
      final handler = http_router.routingHandler([((_) => false, (_) async => response(200))], (
        actual,
      ) async {
        expect(actual, same(input));
        calls++;
        return expected;
      });

      expect(await handler(input), same(expected));
      expect(calls, 1);
    });

    test('list insertion controls route order', () async {
      final visited = <String>[];
      final input = request('/hello');
      final expected = response(201);
      final routes = <(bool Function(Request request), Handler)>[
        (
          (_) => fail('Appended route must not be evaluated'),
          (_) async => fail('Appended handler must not run'),
        ),
      ];
      routes.insert(0, (
        (_) {
          visited.add('first insert');
          return true;
        },
        (actual) async {
          expect(actual, same(input));
          return expected;
        },
      ));
      routes.insert(0, (
        (_) {
          visited.add('latest insert');
          return false;
        },
        (_) async => fail('Non-matching handler must not run'),
      ));
      final handler = http_router.routingHandler(
        routes,
        (_) async => fail('Default handler must not run'),
      );

      expect(await handler(input), same(expected));
      expect(visited, ['latest insert', 'first insert']);
    });

    test('empty route list uses default handler', () async {
      final expected = response(200);
      final handler = http_router.routingHandler([], (_) async => expected);

      expect(await handler(request('/')), same(expected));
    });

    test('propagates handler failures without falling through', () async {
      final error = StateError('handler failed');
      final handler = http_router.routingHandler([
        ((_) => true, (_) async => throw error),
        ((_) => true, (_) async => fail('Must not fall through')),
      ], (_) async => fail('Must not fall through to default'));

      await expectLater(handler(request('/')), throwsA(same(error)));
    });

    test('propagates matcher failures', () async {
      final error = StateError('matcher failed');
      final handler = http_router.routingHandler([
        ((_) => throw error, (_) async => response(200)),
      ], (_) async => fail('Default handler must not run'));

      await expectLater(handler(request('/')), throwsA(same(error)));
    });

    test('propagates default handler failures', () async {
      final error = StateError('default handler failed');
      final handler = http_router.routingHandler([], (_) async => throw error);

      await expectLater(handler(request('/')), throwsA(same(error)));
    });
  });
}
