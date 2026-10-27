import 'dart:convert';

import 'package:http_interop/extensions.dart';
import 'package:json_api/document.dart';
import 'package:test/test.dart';
import 'package:shared/api.dart';

import 'harness.dart';

Future<void> main() async {
  late TestApplication app;
  late TwApiClient client;

  group('Sessions', () {
    setUp(() async {
      app = await startTestApplication();
      client = app.client;
    });

    tearDown(() async {
      await app.stop();
    });

    test('No Auth Header: Unauthorized', () async {
      expect(() => client.listSessions(), statusCode(401));
    });

    test('Session creation supplies a fresh redirect URL for each request', () async {
      final first = await client.createSession();
      final second = await client.createSession();

      expect(first!.attributes['redirect'], isNot(second!.attributes['redirect']));
    });

    test('Google callback nonce is one-time', () async {
      final session = await client.createSession();
      final state = app.googleOAuth.states.last;

      final first = await app.googleCallback('test-code', state: state);
      expect(first.statusCode, 200);

      final replay = await app.googleCallback('replay-code', state: state);
      expect(replay.statusCode, 400);

      expect((await client.listSessions()).map((r) => r.id), [session!.id]);
    });

    test('Session Deletion: Happy Path', () async {
      final first = await client.createSession();
      await app.googleCallback('test-code');

      final secondClient = TwApiClient(app.urlDesign, app.clientHandler);
      final second = await secondClient.createSession();
      await app.googleCallback('updated-code');

      expect((await client.listSessions()).map((r) => r.id), [first!.id, second!.id]);

      await secondClient.deleteSession();

      expect(() => secondClient.listSessions(), statusCode(401));
      expect((await client.listSessions()).map((r) => r.id), [first.id]);
    });

    test("Session Deletion: Can't delete another user's session", () async {
      final first = await client.createSession();
      await app.googleCallback('test-code');
      final firstId = first!.id;

      final secondClient = TwApiClient(app.urlDesign, app.clientHandler);
      final second = await secondClient.createSession();
      app.googleOAuth.email = 'other@example.com';
      app.googleOAuth.name = 'Other User';
      await app.googleCallback('updated-code');

      final secondId = second!.id;

      await expectLater(() => secondClient.fetchSession(firstId), statusCode(404));

      expect(() => secondClient.deleteSessionById(firstId), statusCode(404));

      expect((await client.listSessions()).map((r) => r.id), [firstId]);
      expect((await secondClient.listSessions()).map((r) => r.id), [secondId]);
    });

    test('Session Creation: Happy Path', () async {
      final r0 = await client.createSession();
      expect(r0!.attributes['redirect'], app.googleOAuth.authorizationUri.toString());
      expect(r0.relationships['user'], isA<ToOne>());
      expect(r0.relationships['user']!.isEmpty, isTrue);

      final state = app.googleOAuth.states.last;
      expect(state, isNotEmpty);
      expect(app.googleOAuth.authorizationUri.queryParameters['state'], state);

      final bearer = r0.attributes['key'] as String?;
      expect(bearer, isNotEmpty);
      final otherClient = TwApiClient(app.urlDesign, app.clientHandler);
      await otherClient.createSession();
      final invalidKeyClient = TwApiClient(app.urlDesign, (request) {
        request.headers['Authorization'] = ['Bearer invalid-key'];
        return app.clientHandler(request);
      });
      for (final unauthorizedClient in [
        TwApiClient(app.urlDesign, app.clientHandler),
        invalidKeyClient,
        otherClient,
      ]) {
        await expectLater(() => unauthorizedClient.fetchSession(r0.id), statusCode(401));
      }

      final pendingSession = await client.fetchCurrentSession();
      expect(pendingSession.id, r0.id);
      expect(pendingSession.attributes['key'], bearer);
      expect(pendingSession.relationships['user'], isA<ToOne>());
      expect(pendingSession.relationships['user']!.isEmpty, isTrue);
      expect(await client.fetchCurrentUser(), isNull);
      expect(() => client.listSessions(), statusCode(401));

      await app.googleCallback('test-code', state: state).then((r) async {
        expect(r.statusCode, 200);
        expect(r.headers['content-type'], ['text/html; charset=utf-8']);
        final page = await r.body.decode(utf8);
        expect(page, contains('Thank you, Test User, you may close this page.'));
        expect(page, contains('<span id="countdown">5</span>'));
        expect(page, contains('window.close()'));
        expect(page, isNot(contains(bearer!)));
        expect(page, isNot(contains('user@example.com')));
        expect(app.googleOAuth.queryParameters, {'code': 'test-code', 'state': state});
      });

      final fetchedSessions = await client.listSessions();
      expect(fetchedSessions.map((r) => r.id), [r0.id]);
      expect(fetchedSessions.single.attributes['key'], bearer);

      final completedSession = await client.fetchCurrentSession();
      expect(completedSession.relationships['user'], isA<ToOne>());
      final user = completedSession.relationships['user']!.single;
      expect(user.type, ResourceType.users);
      expect(user.id, isNotEmpty);
      expect(fetchedSessions.single.relationships['user'], isA<ToOne>());
      expect(fetchedSessions.single.relationships['user']!.single.type, user.type);
      expect(fetchedSessions.single.relationships['user']!.single.id, user.id);

      final relatedUser = await client.fetchCurrentUser();
      expect(relatedUser, isNotNull);
      expect(relatedUser, isA<User>());
      expect(relatedUser!.id, user.id);
      expect(relatedUser.email, 'user@example.com');
      expect(relatedUser.name, 'Test User');

      final r1 = await client.createSession();
      final updatedState = app.googleOAuth.states.last;
      final updatedBearer = r1!.attributes['key'] as String?;
      expect(updatedBearer, isNotEmpty);

      app.googleOAuth.name = 'Updated User';
      await app.googleCallback('updated-code', state: updatedState);

      final updatedFetchedSessions = await client.listSessions();
      expect(updatedFetchedSessions.map((r) => r.id), [r0.id, r1.id]);
      expect(updatedFetchedSessions.map((r) => r.attributes['key']), [bearer, updatedBearer]);
    });

    test('Google callback escapes the name in the success page', () async {
      await client.createSession();
      app.googleOAuth.name = 'Alex <script>alert(1)</script> & Co';

      final response = await app.googleCallback('test-code');
      final page = await response.body.decode(utf8);

      expect(response.statusCode, 200);
      expect(
        page,
        contains(
          'Thank you, Alex &lt;script&gt;alert(1)&lt;/script&gt; &amp; Co, you may close this page.',
        ),
      );
      expect(page, isNot(contains(app.googleOAuth.name)));
    });
  });
}
