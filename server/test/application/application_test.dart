import 'dart:convert';

import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart' hide Request;
import 'package:json_api/routing.dart';
import 'package:test/test.dart';

import 'harness.dart';

Future<void> main() async {
  final urlDesign = StandardUriDesign(testConfig.baseUri);
  late TestGoogleOAuth googleOAuth;
  late Handler appHandler;
  late RoutingClient client;

  group('Application', () {
    setUp(() async {
      await resetDatabaseSchema(testConfig);
      googleOAuth = TestGoogleOAuth();
      appHandler = await testApplicationHandler(testConfig, googleOAuth);
      client = RoutingClient(urlDesign, Client(appHandler));
    });

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

      test('Session creation supplies a fresh redirect URL for each request', () async {
        final first = await client.createNew('sessions');
        final second = await client.createNew('sessions');

        expect(
          first.resource.attributes['redirect'],
          isNot(second.resource.attributes['redirect']),
        );
      });

      test('Session Creation: Happy Path', () async {
        final r0 = await client.createNew('sessions');
        expect(r0.resource.attributes['redirect'], googleOAuth.authorizationUri.toString());

        final state = googleOAuth.states.last;
        expect(state, isNotEmpty);
        expect(googleOAuth.authorizationUri.queryParameters['state'], state);

        final createdSession = await fetchSession(testConfig, r0.resource.id);
        expect(createdSession, isNotNull);
        expect(createdSession!.nonce, state);
        expect(createdSession.sessionKey, matches(RegExp(r'^[A-Za-z0-9]{64}$')));
        expect(createdSession.userId, isNull);
        expect(r0.resource.attributes['http_authorization_bearer'], createdSession.sessionKey);
        final authHeaders = {
          'Authorization': ['Bearer ${createdSession.sessionKey}'],
        };
        expect(
          () => client.fetchCollection('sessions', headers: authHeaders),
          throwsA(
            isA<RequestFailure>().having(
              (r) => r.rawResponse.httpResponse.statusCode,
              'Status Code',
              equals(401),
            ),
          ),
        );

        await appHandler(
          Request(
            'get',
            Uri(
              path: '/auth/google/callback',
              queryParameters: {'code': 'test-code', 'state': state},
            ),
            Body(),
            Headers(),
          ),
        ).then((r) async {
          expect(r.statusCode, 200);
          expect(await r.body.decode(utf8), '''
Signed in with Google. Session: ${createdSession.sessionKey}
Email: user@example.com
Name: Test User''');
          expect(googleOAuth.queryParameters, {'code': 'test-code', 'state': state});
        });

        final user = await fetchUserByEmail(testConfig, 'user@example.com');
        expect(user, isNotNull);
        expect(user!.email, 'user@example.com');
        expect(user.name, 'Test User');

        final session = await fetchSession(testConfig, r0.resource.id);
        expect(session, isNotNull);
        expect(session!.sessionKey, createdSession.sessionKey);
        expect(session.nonce, isNull);
        expect(session.userId, user.id);

        final fetchedSessions = await client.fetchCollection('sessions', headers: authHeaders);
        expect(fetchedSessions.collection.map((r) => r.id), [session.id]);
        expect(
          fetchedSessions.collection.single.attributes['http_authorization_bearer'],
          createdSession.sessionKey,
        );

        final r1 = await client.createNew('sessions');
        final updatedState = googleOAuth.states.last;
        final createdUpdatedSession = await fetchSession(testConfig, r1.resource.id);
        expect(createdUpdatedSession, isNotNull);
        expect(createdUpdatedSession!.nonce, updatedState);
        expect(createdUpdatedSession.sessionKey, matches(RegExp(r'^[A-Za-z0-9]{64}$')));
        expect(createdUpdatedSession.userId, isNull);

        googleOAuth.name = 'Updated User';
        googleOAuth.sessionId = 'updated-session-id';
        await appHandler(
          Request(
            'get',
            Uri(
              path: '/auth/google/callback',
              queryParameters: {'code': 'updated-code', 'state': updatedState},
            ),
            Body(),
            Headers(),
          ),
        );

        final updatedUser = await fetchUserByEmail(testConfig, 'user@example.com');
        expect(updatedUser, isNotNull);
        expect(updatedUser!.id, user.id);
        expect(updatedUser.name, 'Updated User');

        final updatedSession = await fetchSession(testConfig, r1.resource.id);
        expect(updatedSession, isNotNull);
        expect(updatedSession!.sessionKey, createdUpdatedSession.sessionKey);
        expect(updatedSession.nonce, isNull);
        expect(updatedSession.userId, user.id);

        final updatedFetchedSessions = await client.fetchCollection(
          'sessions',
          headers: authHeaders,
        );
        expect(updatedFetchedSessions.collection.map((r) => r.id), [session.id, updatedSession.id]);
      });
    });
  });
}
