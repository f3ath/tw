import 'package:http_interop/http_interop.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';

TwApiClient _client([Handler? handler]) => TwApiClient(
  StandardUriDesign(Uri.parse('https://example.test/api')),
  handler ?? (_) async => fail('Unexpected HTTP request'),
);

Response _sessionResponse({int status = 200}) => Response(
  status,
  Body.text('{"data":{"type":"sessions","id":"session-1"}}'),
  Headers.from({
    'Content-Type': ['application/vnd.api+json'],
  }),
);

void main() {
  late TwApiClient client;

  setUp(() {
    client = _client();
  });

  group('saveState', () {
    test('returns an empty string without a session', () {
      expect(client.saveState(), '');
    });

    test('round-trips the session ID and token', () {
      client.restoreState('session-1:secret-token');

      expect(client.saveState(), 'session-1:secret-token');
    });

    test('throws when the session has no token', () async {
      client = _client((_) async => _sessionResponse(status: 201));
      expectLater(client.createSession(), throwsA(isA<InvalidResponse>()));

      expect(client.saveState(), '');
    });
  });

  group('restoreState', () {
    test('restores the session ID and bearer token for subsequent requests', () async {
      client = _client((request) async {
        expect(request.uri.path, '/api/sessions/session-1');
        expect(request.headers['Authorization'], ['Bearer secret-token']);
        return _sessionResponse();
      });

      client.restoreState('session-1:secret-token');

      expect((await client.fetchCurrentSession()).id, 'session-1');
    });

    test('replaces an existing session', () {
      client.restoreState('old-session:old-token');

      client.restoreState('new-session:new-token');

      expect(client.saveState(), 'new-session:new-token');
    });

  });
}
