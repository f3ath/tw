import 'dart:convert';

import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart' hide Request;
import 'package:json_api/routing.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/application/application.dart';

import 'harness.dart';

Future<void> main() async {
  final baseUri = Uri.parse('http://localhost:8080/api/v0');
  final urlDesign = StandardUriDesign(baseUri);
  final config = AppConfig(
    baseUri: baseUri,
    googleOAuthClientId: 'test-client-id',
    googleOAuthClientSecret: 'test-client-secret',
    databaseHost: 'localhost',
    databasePort: 5432,
    databaseName: 'tw_e2e',
    databaseUsername: 'tw',
    databasePassword: 'tw',
  );
  final googleOAuth = TestGoogleOAuth();
  final appHandler = await testApplicationHandler(config, googleOAuth);
  final client = RoutingClient(urlDesign, Client(appHandler));

  group('Application', () {
    group('Sessions', () {
      test('No Auth Header: Unauthorized', () async {
        expect(
          () => client.fetchCollection('sessions'),
          throwsA(
            isA<RequestFailure>().having(
              (r) => r.rawResponse.httpResponse.statusCode,
              'Status Code',
              equals(401),
            ),
          ),
        );
      });
      test('Session Creation: Happy Path', () async {
        final r0 = await client.createNew('sessions');
        expect(r0.resource.id, '1');
        expect(r0.resource.attributes['redirect'], googleOAuth.authorizationUri.toString());

        await appHandler(
          Request(
            'get',
            Uri.parse('/auth/google/callback?code=test-code&state=test-state'),
            Body(),
            Headers(),
          ),
        ).then((r) async {
          expect(r.statusCode, 200);
          expect(await r.body.decode(utf8), '''
Signed in with Google. Session: test-session-id
Email: user@example.com
Name: Test User''');
          expect(googleOAuth.queryParameters, {'code': 'test-code', 'state': 'test-state'});
        });
      });
    });
  });
}
