import 'dart:async';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/routing.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/app/app.dart';
import 'package:tw_server/src/db/connection_from_config.dart';
import 'package:tw_server/src/log/log.dart';
import 'package:tw_server/tw_server.dart';

import 'harness.dart';

Request get(String path) => Request('get', Uri(path: path), Body(), Headers());

void main() {
  late App app;
  late List<Connection> connections;
  late StartupLog log;

  setUp(() async {
    await resetDatabaseSchema(testConfig);
    connections = [];
    log = StartupLog();
    app = App(
      testConfig,
      googleOAuth: TestGoogleOAuth(),
      log: log,
      connectionFactory: (config) async {
        final connection = await connectionFromConfig(config);
        connections.add(connection);
        return connection;
      },
    );
  });

  tearDown(() async {
    await app.stop();
    for (final connection in connections) {
      await connection.close();
    }
  });

  test('Repeated and concurrent starts share one connection', () async {
    await Future.wait([app.start(), app.start()]);
    await app.start();

    expect(connections, hasLength(1));
    expect(connections.single.isOpen, isTrue);
    expect((await app(get('/k8s/readiness'))).statusCode, 200);
  });

  test('Stop closes the connection and removes routes; restart installs fresh routes', () async {
    await app.stop();
    await app.start();
    final client = TwApiClient(StandardUriDesign(testConfig.baseUri), app.call);
    final first = await client.createSession();

    await Future.wait([app.stop(), app.stop()]);
    await app.stop();

    expect(connections.single.isOpen, isFalse);
    expect((await app(get('/k8s/readiness'))).statusCode, 500);
    expect((await app(get('/k8s/liveness'))).statusCode, 200);
    expect((await app(get('/api/v0/sessions'))).statusCode, 404);
    expect((await app(get('/auth/google/callback'))).statusCode, 404);

    await app.start();

    expect(connections, hasLength(2));
    expect(connections.last.isOpen, isTrue);
    expect((await app(get('/k8s/readiness'))).statusCode, 200);
    final second = await client.createSession();
    expect(second!.id, isNot(first!.id));
  });

  test('Failed startup closes the connection and allows a retry', () async {
    log.failure = StateError('Startup failed');
    final starting = expectLater(app.start(), throwsA(same(log.failure)));
    final stopping = app.stop();
    await Future.wait([starting, stopping]);

    expect(connections.single.isOpen, isFalse);
    expect((await app(get('/k8s/readiness'))).statusCode, 500);
    expect((await app(get('/api/v0/sessions'))).statusCode, 404);

    log.failure = null;
    await app.start();

    expect(connections, hasLength(2));
    expect(connections.last.isOpen, isTrue);
    expect((await app(get('/k8s/readiness'))).statusCode, 200);
  });

  test('Stop waits for startup and closes its connection', () async {
    final opening = Completer<void>();
    final proceed = Completer<void>();
    app = App(
      testConfig,
      googleOAuth: TestGoogleOAuth(),
      connectionFactory: (config) async {
        opening.complete();
        await proceed.future;
        final connection = await connectionFromConfig(config);
        connections.add(connection);
        return connection;
      },
    );

    final starting = app.start();
    await opening.future;
    final stopping = app.stop();
    proceed.complete();
    await Future.wait([starting, stopping]);

    expect(connections.single.isOpen, isFalse);
    expect((await app(get('/k8s/readiness'))).statusCode, 500);
    expect((await app(get('/api/v0/sessions'))).statusCode, 404);
  });

  test('Start during shutdown waits and opens a fresh connection', () async {
    await app.start();

    final stopping = app.stop();
    final restarting = app.start();
    await Future.wait([stopping, restarting]);

    expect(connections, hasLength(2));
    expect(connections.first.isOpen, isFalse);
    expect(connections.last.isOpen, isTrue);
    expect((await app(get('/k8s/readiness'))).statusCode, 200);
    final client = TwApiClient(StandardUriDesign(testConfig.baseUri), app.call);
    expect(await client.createSession(), isNotNull);
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
