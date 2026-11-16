import 'package:http_interop/http_interop.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  final harness = TestHarness();

  setUp(() async {
    await harness.startServer();
  });

  tearDown(() async {
    await harness.stopServer();
  });

  test('listing sessions requires authentication', () async {
    final client = harness.newClient();
    await expectLater(client.listSessions(), throwsStatusCode(401));
  });

  test('current session require authentication', () async {
    expect(
      await harness.handler(
        Request('GET', Uri(path: '/api/v0/sessions/current'), Body.empty(), Headers()),
      ),
      isA<Response>().having((it) => it.statusCode, 'Status', equals(401)),
    );
    expect(
      await harness.handler(
        Request('GET', Uri(path: '/api/v0/sessions/current/user'), Body.empty(), Headers()),
      ),
      isA<Response>().having((it) => it.statusCode, 'Status', equals(401)),
    );
  });

  test('pending sessions have no user and cannot list sessions', () async {
    final client = harness.newClient();
    await client.createSession();

    expect(await client.fetchCurrentUser(), isNull);
    await expectLater(client.listSessions(), throwsStatusCode(401));
  });

  test('signing out removes only the selected session', () async {
    final client1 = await harness.login();
    final user = await client1.fetchCurrentUser();
    final email = user!.email;
    final session1 = await client1.fetchCurrentSession();
    final client2 = await harness.login(email: email);
    final session2 = await client2.fetchCurrentSession();
    expect(
      (await client1.listSessions()).map((it) => it.id),
      unorderedEquals([session1.id, session2.id]),
    );

    await client2.deleteCurrentSession();
    await expectLater(client2.listSessions(), throwsStatusCode(401));
    expect((await client1.listSessions()).single.id, session1.id);
  });

  test("users cannot read or delete another user's session", () async {
    final first = await harness.login();
    final firstId = (await first.fetchCurrentSession()).id;
    final second = await harness.login();
    final secondId = (await second.fetchCurrentSession()).id;

    await expectLater(second.fetchSession(firstId), throwsStatusCode(404));
    await expectLater(second.deleteSessionById(firstId), throwsStatusCode(404));
    expect((await second.listSessions()).single.id, secondId);
    expect((await first.listSessions()).single.id, firstId);
  });

  test('signing in links the session to the user without exposing tokens', () async {
    final email = '${const Uuid().v4()}@example.com';
    final client = await harness.login(email: email, name: 'Test User');
    final completed = await client.fetchCurrentSession();
    final sessions = await client.listSessions();
    expect(sessions.single.id, completed.id);
    final user = (await client.fetchCurrentUser())!;
    expect(user.email, email);
    expect(user.name, 'Test User');

    final second = await harness.login(email: email, name: 'Updated User');
    final secondId = (await second.fetchCurrentSession()).id;
    expect(
      (await client.listSessions()).map((session) => session.id),
      unorderedEquals([completed.id, secondId]),
    );
    final updated = (await client.fetchCurrentUser())!;
    expect(updated.id, user.id);
    expect(updated.name, 'Updated User');
  });
}
