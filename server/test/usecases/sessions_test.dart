import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = TestHarness();
    await harness.startServer();
  });

  tearDown(() async {
    await harness.stopServer();
  });

  test('sessions require authentication', () async {
    await expectLater(harness.newClient().listSessions(), statusCode(401));
  });

  test('pending sessions have no user and cannot list sessions', () async {
    final client = harness.newClient();
    await client.createSession();

    expect(await client.fetchCurrentUser(), isNull);
    await expectLater(client.listSessions(), statusCode(401));
  });

  test('signing out removes only the selected session', () async {
    final first = await harness.login();
    final user = (await first.fetchCurrentUser())!;
    final firstId = (await first.fetchCurrentSession()).id;
    final second = await harness.login(email: user.email);
    final secondId = (await second.fetchCurrentSession()).id;
    final secondState = second.saveState();
    expect(
      (await first.listSessions()).map((session) => session.id),
      unorderedEquals([firstId, secondId]),
    );

    await second.deleteSession();
    await expectLater(second.listSessions(), statusCode(401));
    second.restoreState(secondState);
    await expectLater(second.listSessions(), statusCode(401));
    expect((await first.listSessions()).single.id, firstId);
  });

  test("users cannot read or delete another user's session", () async {
    final first = await harness.login();
    final firstId = (await first.fetchCurrentSession()).id;
    final second = await harness.login();
    final secondId = (await second.fetchCurrentSession()).id;

    await expectLater(second.fetchSession(firstId), statusCode(404));
    await expectLater(second.deleteSessionById(firstId), statusCode(404));
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
