import 'package:http_interop/http_interop.dart';
import 'package:json_api/routing.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:server/src/server/server.dart';
import 'package:server/src/db/connection_from_config.dart';
import 'package:server/src/log/log.dart';
import 'package:shared/api.dart';

import 'harness.dart';

Request get(String path) => Request('GET', Uri(path: path), Body.empty(), Headers());

void main() {
  late Server testServer;
  late List<Connection> connections;
  late List<Connection> systemConnections;
  late StartupLog log;

  setUp(() async {
    await resetDatabaseSchema(testConfig);
    connections = [];
    systemConnections = [];
    log = StartupLog();
    testServer = Server(
      testConfig,
      log: log,
      systemConnectionFactory: (config) async {
        final connection = await SystemConnection.fromConfig(config);
        systemConnections.add(connection);
        return connection;
      },
      tenantConnectionFactory: (config) async {
        final connection = await TenantConnection.fromConfig(config);
        connections.add(connection);
        return connection;
      },
    );
  });

  tearDown(() async {
    await testServer.stop();
    for (final connection in [...connections, ...systemConnections]) {
      await connection.close();
    }
  });

  test('Startup opens the tenant connection and closes the migration connection', () async {
    await testServer.start();

    expect(systemConnections, hasLength(1));
    expect(systemConnections.single.isOpen, isFalse);
    expect(connections, hasLength(1));
    expect(connections.single.isOpen, isTrue);
    expect((await testServer(get('/k8s/readiness'))).statusCode, 200);
  });

  test('Stop closes the connection and removes routes; restart installs fresh routes', () async {
    await testServer.start();
    final client = TwApiClient(StandardUriDesign(testConfig.baseUri), testServer.call);
    final first = await client.createSession();

    await testServer.stop();

    expect(connections.single.isOpen, isFalse);
    expect((await testServer(get('/k8s/readiness'))).statusCode, 500);
    expect((await testServer(get('/k8s/liveness'))).statusCode, 200);
    await expectLater(client.createSession(), statusCode(404));
    expect((await testServer(get('/auth/google/callback'))).statusCode, 404);

    await testServer.start();

    expect(connections, hasLength(2));
    expect(connections.last.isOpen, isTrue);
    expect((await testServer(get('/k8s/readiness'))).statusCode, 200);
    final second = await client.createSession();
    expect(second!.id, isNot(first!.id));
  });

  test('Failed startup closes the connection and allows a retry', () async {
    log.failure = StateError('Startup failed');
    await expectLater(testServer.start(), throwsA(same(log.failure)));

    expect(systemConnections.single.isOpen, isFalse);
    expect(connections, isEmpty);
    expect((await testServer(get('/k8s/readiness'))).statusCode, 500);
    final client = TwApiClient(StandardUriDesign(testConfig.baseUri), testServer.call);
    await expectLater(client.createSession(), statusCode(404));

    log.failure = null;
    await testServer.start();

    expect(systemConnections, hasLength(2));
    expect(systemConnections.every((connection) => !connection.isOpen), isTrue);
    expect(connections, hasLength(1));
    expect(connections.last.isOpen, isTrue);
    expect((await testServer(get('/k8s/readiness'))).statusCode, 200);
  });
}

class StartupLog() implements Log {
  Object? failure;

  @override
  void log(
    LogLevel level,
    Object? message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (message == 'Migrations applied.' && failure != null) throw failure!;
  }
}
