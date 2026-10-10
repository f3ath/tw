import 'dart:convert';

import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart' hide Request;
import 'package:json_api/routing.dart';
import 'package:test/test.dart';
import 'package:tw_server/tw_server.dart';

import 'harness.dart';

Future<void> main() async {
  final urlDesign = StandardUriDesign(testConfig.baseUri);
  late TestGoogleOAuth googleOAuth;
  late Handler appHandler;
  late TwApiClient client;

  Future<Response> googleCallback(String code, {String? state}) => appHandler(
    Request(
      'get',
      Uri(
        path: '/auth/google/callback',
        queryParameters: {'code': code, 'state': state ?? googleOAuth.states.last},
      ),
      Body(),
      Headers(),
    ),
  );

  group('Sessions', () {
    setUp(() async {
      await resetDatabaseSchema(testConfig);
      googleOAuth = TestGoogleOAuth();
      appHandler = await testApplicationHandler(testConfig, googleOAuth);
      client = TwApiClient(urlDesign, appHandler);
    });

    test('No Auth Header: Unauthorized', () async {
      expect(
        () => client.listSessions(),
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
      final first = await client.createSession();
      final second = await client.createSession();

      expect(first!.attributes['redirect'], isNot(second!.attributes['redirect']));
    });

    test('Google callback nonce is one-time', () async {
      final session = await client.createSession();
      final state = googleOAuth.states.last;

      final first = await googleCallback('test-code', state: state);
      expect(first.statusCode, 200);

      final replay = await googleCallback('replay-code', state: state);
      expect(replay.statusCode, 400);
      expect(await replay.body.decode(utf8), 'Invalid Google callback.');

      expect((await client.listSessions()).map((r) => r.id), [session!.id]);
    });

    test('Session Deletion: Happy Path', () async {
      final first = await client.createSession();
      await googleCallback('test-code');

      final secondClient = TwApiClient(urlDesign, appHandler);
      final second = await secondClient.createSession();
      await googleCallback('updated-code');

      expect((await client.listSessions()).map((r) => r.id), [first!.id, second!.id]);

      await secondClient.deleteSession();

      expect(
        () => secondClient.listSessions(),
        throwsA(
          isA<RequestFailure>().having(
            (r) => r.rawResponse.httpResponse.statusCode,
            'Status Code',
            equals(401),
          ),
        ),
      );
      expect((await client.listSessions()).map((r) => r.id), [first.id]);
    });

    test("Session Deletion: Can't delete another user's session", () async {
      final first = await client.createSession();
      await googleCallback('test-code');
      final firstId = first!.id;

      final secondClient = TwApiClient(urlDesign, appHandler);
      final second = await secondClient.createSession();
      googleOAuth.email = 'other@example.com';
      googleOAuth.name = 'Other User';
      await googleCallback('updated-code');

      final secondId = second!.id;

      expect(
        () => secondClient.deleteSessionById(firstId),
        throwsA(
          isA<RequestFailure>().having(
            (r) => r.rawResponse.httpResponse.statusCode,
            'Status Code',
            equals(404),
          ),
        ),
      );

      expect((await client.listSessions()).map((r) => r.id), [firstId]);
      expect((await secondClient.listSessions()).map((r) => r.id), [secondId]);
    });

    test('Session Creation: Happy Path', () async {
      final r0 = await client.createSession();
      expect(r0!.attributes['redirect'], googleOAuth.authorizationUri.toString());

      final state = googleOAuth.states.last;
      expect(state, isNotEmpty);
      expect(googleOAuth.authorizationUri.queryParameters['state'], state);

      final bearer = r0.attributes['http_authorization_bearer'] as String?;
      expect(bearer, isNotEmpty);
      expect(
        () => client.listSessions(),
        throwsA(
          isA<RequestFailure>().having(
            (r) => r.rawResponse.httpResponse.statusCode,
            'Status Code',
            equals(401),
          ),
        ),
      );

      await googleCallback('test-code', state: state).then((r) async {
        expect(r.statusCode, 200);
        expect(await r.body.decode(utf8), '''
Signed in with Google. Session: $bearer
Email: user@example.com
Name: Test User''');
        expect(googleOAuth.queryParameters, {'code': 'test-code', 'state': state});
      });

      final fetchedSessions = await client.listSessions();
      expect(fetchedSessions.map((r) => r.id), [r0.id]);
      expect(fetchedSessions.single.attributes['http_authorization_bearer'], bearer);

      final r1 = await client.createSession();
      final updatedState = googleOAuth.states.last;
      final updatedBearer = r1!.attributes['http_authorization_bearer'] as String?;
      expect(updatedBearer, isNotEmpty);

      googleOAuth.name = 'Updated User';
      await googleCallback('updated-code', state: updatedState);

      final updatedFetchedSessions = await client.listSessions();
      expect(updatedFetchedSessions.map((r) => r.id), [r0.id, r1.id]);
      expect(updatedFetchedSessions.map((r) => r.attributes['http_authorization_bearer']), [
        bearer,
        updatedBearer,
      ]);
    });
  });
}
