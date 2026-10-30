import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:server/src/auth/google_oauth.dart';
import 'package:test/test.dart';

const _endpoints = GoogleAuthEndpoints();
const _callbackParams = {'code': 'authorization-code', 'state': 'nonce & value'};

http.Response _tokenResponse() => http.Response(
  jsonEncode({
    'access_token': 'access-token',
    'token_type': 'Bearer',
    'expires_in': 3600,
    'scope': 'openid email profile',
  }),
  200,
  headers: {'content-type': 'application/json'},
);

GoogleOAuthClient _oauth(http.Client Function() factory) => GoogleOAuthClient(
  clientId: 'client-id',
  clientSecret: 'client-secret',
  redirectUri: 'https://example.test/callback',
  clientFactory: factory,
);

class _TrackingClient(super.handler) extends MockClient {
  int closeCount = 0;

  @override
  void close() {
    closeCount++;
    super.close();
  }
}

void main() {
  group('GoogleOAuthClient', () {
    test('builds the authorization URL without creating an HTTP client', () {
      final uri = _oauth(() => throw StateError('Unexpected HTTP client'))
          .startAuthorization('nonce & value');
      expect(uri.origin, _endpoints.authorizationEndpoint.origin);
      expect(uri.path, _endpoints.authorizationEndpoint.path);
      expect(uri.queryParameters, {
        'client_id': 'client-id',
        'redirect_uri': 'https://example.test/callback',
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': 'nonce & value',
        'access_type': 'offline',
        'prompt': 'consent',
      });
    });

    test('rejects missing callback parameters without creating an HTTP client', () async {
      var creations = 0;
      final oauth = _oauth(() {
        creations++;
        throw StateError('Unexpected HTTP client');
      });
      for (final parameters in [
        <String, String>{},
        {'code': 'code'},
        {'state': 'state'},
      ]) {
        expect(await oauth.finishAuthorization(parameters), isNull);
      }
      expect(creations, 0);
    });

    test('exchanges the code and fetches the user with the access token', () async {
      final requests = <http.Request>[];
      final client = _TrackingClient((request) async {
        requests.add(request);
        if (request.url == _endpoints.tokenEndpoint) return _tokenResponse();
        return http.Response('{"email":"user@example.test","name":"Test User"}', 200);
      });
      final session = await _oauth(() => client).finishAuthorization(_callbackParams);
      expect(session, isNotNull);
      expect(session!.email, 'user@example.test');
      expect(session.name, 'Test User');
      expect(session.nonce, _callbackParams['state']);
      expect(requests, hasLength(2));
      expect(requests.first.method, 'POST');
      expect(requests.first.url, _endpoints.tokenEndpoint);
      expect(requests.first.bodyFields, {
        'client_id': 'client-id',
        'client_secret': 'client-secret',
        'code': 'authorization-code',
        'grant_type': 'authorization_code',
        'redirect_uri': 'https://example.test/callback',
      });
      expect(requests.last.method, 'GET');
      expect(requests.last.url.toString(), 'https://openidconnect.googleapis.com/v1/userinfo');
      expect(requests.last.headers['authorization'], 'Bearer access-token');
      expect(client.closeCount, 1);
    });

    test('defaults absent profile fields to empty strings', () async {
      final client = _TrackingClient(
        (request) async =>
            request.url == _endpoints.tokenEndpoint ? _tokenResponse() : http.Response('{}', 200),
      );
      final session = await _oauth(() => client).finishAuthorization(_callbackParams);
      expect(session, isNotNull);
      expect(session!.email, isEmpty);
      expect(session.name, isEmpty);
      expect(client.closeCount, 1);
    });

    for (final status in [400, 500]) {
      test('rejects token exchange status $status and closes the client', () async {
        var requests = 0;
        final client = _TrackingClient((request) async {
          requests++;
          return http.Response('{"error":"invalid_grant"}', status);
        });
        expect(await _oauth(() => client).finishAuthorization(_callbackParams), isNull);
        expect(requests, 1);
        expect(client.closeCount, 1);
      });
    }

    for (final response in [
      http.Response('Forbidden', 403),
      http.Response('Unavailable', 503),
      http.Response('invalid json', 200),
      http.Response('[]', 200),
      http.Response('{"email":42}', 200),
      http.Response('{"name":42}', 200),
    ]) {
      test('rejects invalid user info: ${response.statusCode} ${response.body}', () async {
        final client = _TrackingClient(
          (request) async => request.url == _endpoints.tokenEndpoint ? _tokenResponse() : response,
        );
        expect(await _oauth(() => client).finishAuthorization(_callbackParams), isNull);
        expect(client.closeCount, 1);
      });
    }

    test('closes the client on a transport failure', () async {
      final client = _TrackingClient((_) async => throw http.ClientException('Connection failed'));
      expect(await _oauth(() => client).finishAuthorization(_callbackParams), isNull);
      expect(client.closeCount, 1);
    });
  });
}
