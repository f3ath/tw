import 'package:test/test.dart';
import 'package:server/src/server/server.dart';
import 'package:server/src/auth/sessions_dao.dart';
import 'package:server/src/db/database.dart';

import 'harness.dart';

void main() {
  late TestServer testServer;
  setUp(() async {
    testServer = await startTestServer();
  });
  tearDown(() async {
    await testServer.stop();
  });

  test('server runs configured cleanup and cancels it on shutdown, then restarts it', () async {
    await testServer.stop();
    final config = createTestConfig(
      sessionCleanupInterval: const Duration(seconds: 1),
      pendingSessionMaxAge: const Duration(minutes: 10),
    );
    var now = DateTime.utc(2026, 1, 1, 12);
    DateTime clock() => now;
    final server = Server(config, oauth: TestGoogleOAuth(), clock: clock);
    addTearDown(server.stop);
    await server.start();
    await withTestDatabase(config, (connection) async {
      final sessions = SessionsDAO(Database(connection), clock: clock);
      now = now.subtract(const Duration(minutes: 11));
      final expired = await sessions.create();
      now = now.add(const Duration(minutes: 11));
      final fresh = await sessions.create();

      Future<void> expectDeleted(String id) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (await sessions.fetch(id) != null && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(await sessions.fetch(id), isNull);
      }

      await expectDeleted(expired.id);
      expect(await sessions.fetch(fresh.id), isNotNull);

      await server.stop();
      now = now.add(const Duration(minutes: 11));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(await sessions.fetch(fresh.id), isNotNull);

      await server.start();
      await expectDeleted(fresh.id);
    });
  });

  test('deletes only unlinked sessions strictly older than the configured age', () async {
    await withTestDatabase(testConfig, (connection) async {
      final current = DateTime.utc(2026, 1, 1, 12);
      var now = current;
      DateTime clock() => now;
      final sessions = SessionsDAO(Database(connection), clock: clock);
      now = current.subtract(const Duration(seconds: 901));
      final expired = await sessions.create();
      now = current.subtract(const Duration(seconds: 900));
      final boundary = await sessions.create();
      now = current.subtract(const Duration(seconds: 899));
      final fresh = await sessions.create();
      now = current;

      await sessions.deletePendingOlderThan(const Duration(minutes: 15));
      expect(await sessions.fetch(expired.id), isNull);
      for (final session in [boundary, fresh]) {
        expect(await sessions.fetch(session.id), isNotNull);
      }
      await sessions.deletePendingOlderThan(const Duration(minutes: 10));
      expect(await sessions.fetch(boundary.id), isNull);
      expect(await sessions.fetch(fresh.id), isNull);
    });
  });
}
