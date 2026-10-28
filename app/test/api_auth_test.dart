import 'dart:convert';

import 'package:app/app/composition.dart';
import 'package:app/app/torque_wrench_app.dart';
import 'package:app/data/services/services.dart';
import 'package:flutter/material.dart';

import 'package:app/data/repositories/api_auth_repository.dart';
import 'package:app/data/repositories/local_repositories.dart';
import 'package:app/data/services/api_auth_service.dart';
import 'package:app/data/services/oauth_window.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/session_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

class FakeOAuthWindow() implements OAuthWindow {
  Uri? redirect;
  bool closed = false;
  bool cancelled = false;
  @override
  bool get isClosed => cancelled;
  @override
  Future<void> navigate(Uri uri) async {
    redirect = uri;
  }

  @override
  void close() {
    closed = true;
  }
}

class FailingRemovalStorage() extends MemoryStorage {
  bool failRemoval = true;
  @override
  Future<void> remove(String key) async {
    if (failRemoval) throw StateError('storage unavailable');
    await super.remove(key);
  }
}

http.Response jsonResponse(Object? data, {int status = 200}) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/vnd.api+json'},
);

final user = {
  'type': 'users',
  'id': 'u1',
  'attributes': {'email': 'real@example.com', 'name': 'Real User'},
};
final pending = {
  'type': 'sessions',
  'id': 's1',
  'attributes': {'key': 'secret', 'redirect': 'https://accounts.google.com/authorize'},
};

void main() {
  late MemoryStorage persistence;
  late LocalSettingsRepository settings;
  late FakeOAuthWindow window;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  ApiAuthService service({Duration timeout = const Duration(seconds: 1)}) => ApiAuthService(
    settings,
    persistence,
    windowFactory: () => window,
    httpClientFactory: () => MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    pollInterval: Duration.zero,
    signInTimeout: timeout,
  );

  setUp(() {
    persistence = MemoryStorage();
    settings = LocalSettingsRepository(persistence);
    window = FakeOAuthWindow();
    requests = [];
    respond = (request) async {
      if (request.method.toUpperCase() == 'POST') return jsonResponse(pending, status: 201);
      if (request.method.toUpperCase() == 'DELETE') return http.Response('', 204);
      return jsonResponse(user);
    };
  });

  test('login polls TwApiClient with saved URL and bearer; restore and logout revoke it', () async {
    await settings.save('https://saved.example/custom/api');
    var polls = 0;
    final normal = respond;
    respond = (request) async {
      if (request.method.toUpperCase() == 'GET' && polls++ == 0) return jsonResponse(null);
      return normal(request);
    };
    final auth = ApiAuthRepository(service());
    final maintenance = FakeMaintenanceRepository();
    final session = SessionUseCase(auth, maintenance);
    await session.signIn();
    expect(auth.identity, 'real@example.com');
    expect(window.redirect.toString(), 'https://accounts.google.com/authorize');
    expect(window.closed, isTrue);
    expect(requests.first.url.toString(), 'https://saved.example/custom/api/sessions');
    expect(requests.skip(1).map((r) => r.headers['Authorization']), everyElement('Bearer secret'));
    expect(persistence.values['session'], {
      'id': 's1',
      'key': 'secret',
      'address': 'https://saved.example/custom/api',
    });

    final restored = ApiAuthRepository(service());
    await restored.restore();
    expect(restored.identity, auth.identity);
    expect(requests.last.url.path, '/custom/api/sessions/s1/user');
    await settings.save('https://different.example/api');
    await restored.signOut();
    expect(requests.last.method.toUpperCase(), 'DELETE');
    expect(requests.last.url.toString(), 'https://saved.example/custom/api/sessions/s1');
    expect(requests.last.headers['Authorization'], 'Bearer secret');
    expect(restored.identity, isNull);
    expect(persistence.values['session'], isNull);
  });

  test('expired session is removed; failed logout preserves session for retry', () async {
    final auth = ApiAuthRepository(service());
    await auth.signIn();
    respond = (_) async => http.Response('', 503);
    await expectLater(auth.signOut(), throwsA(isA<AppFailure>()));
    expect(auth.identity, 'real@example.com');
    expect(persistence.values['session'], isNotNull);
    respond = (_) async => http.Response('', 401);
    final restored = ApiAuthRepository(service());
    await restored.restore();
    expect(restored.identity, isNull);
    expect(persistence.values['session'], isNull);
  });

  test('changed config never sends saved bearer to another server', () async {
    await ApiAuthRepository(service()).signIn();
    requests.clear();
    await settings.save('https://another.example/api/v0');
    final auth = ApiAuthRepository(service());
    await auth.restore();
    expect(auth.identity, isNull);
    expect(requests, isEmpty);
    expect(persistence.values['session'], isNull);
  });

  test(
    'cancelled, timed out and failed sign-ins close the window without persisting a session',
    () async {
      respond = (request) async => request.method.toUpperCase() == 'POST'
          ? jsonResponse(pending, status: 201)
          : jsonResponse(null);
      window.cancelled = true;
      await expectLater(service().signIn(), throwsA(isA<AppFailure>()));
      expect(window.closed, isTrue);
      expect(persistence.values['session'], isNull);
      window = FakeOAuthWindow();
      await expectLater(service(timeout: Duration.zero).signIn(), throwsA(isA<AppFailure>()));
      expect(window.closed, isTrue);
      window = FakeOAuthWindow();
      respond = (_) async => throw http.ClientException('offline');
      await expectLater(
        service().signIn(),
        throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.connectivity)),
      );
      expect(window.closed, isTrue);
      expect(persistence.values['session'], isNull);
    },
  );

  test('logout retries local cleanup after the server session has been revoked', () async {
    final flaky = FailingRemovalStorage();
    persistence = flaky;
    settings = LocalSettingsRepository(persistence);
    final auth = ApiAuthRepository(service());
    await auth.signIn();
    await expectLater(auth.signOut(), throwsA(isA<AppFailure>()));
    flaky.failRemoval = false;
    await auth.signOut();
    expect(auth.identity, isNull);
    expect(persistence.values['session'], isNull);
    expect(requests.where((r) => r.method.toUpperCase() == 'DELETE'), hasLength(1));
  });

  test('temporary restore failure keeps credentials for retry', () async {
    await ApiAuthRepository(service()).signIn();
    respond = (_) async => http.Response('', 503);
    final auth = ApiAuthRepository(service());
    await expectLater(auth.restore(), throwsA(isA<AppFailure>()));
    expect(persistence.values['session'], isNotNull);
    respond = (_) async => jsonResponse(user);
    await auth.restore();
    expect(auth.identity, 'real@example.com');
  });

  testWidgets('Google login and failed logout retry use the actual API flow', (tester) async {
    final composition = Composition(
      auth: ApiAuthRepository(service()),
      maintenance: LocalMaintenanceRepository(
        persistence,
        DemoSimulation(delay: Duration.zero),
        clock: () => DateTime(2026, 10, 27),
        idGenerator: () => 'id',
        emptySeed: true,
      ),
      settings: settings,
      clock: () => DateTime(2026, 10, 27),
    );
    await tester.pumpWidget(TorqueWrenchApp(composition: composition));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsNothing);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('real@example.com'), findsOneWidget);
    respond = (_) async => http.Response('', 503);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(composition.session.identity, 'real@example.com');
    respond = (_) async => http.Response('', 204);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(requests.last.method.toUpperCase(), 'DELETE');
    expect(persistence.values['session'], isNull);
    await tester.pumpWidget(const SizedBox());
    composition.dispose();
  });

  test('default and legacy saved config use API prefix while custom settings survive', () async {
    expect(await settings.load(), 'http://localhost:8080/api/v0');
    await persistence.write('settings', {'address': 'http://localhost:8080'});
    expect(await settings.load(), 'http://localhost:8080/api/v0');
    expect(persistence.values['settings']?['address'], 'http://localhost:8080/api/v0');
    await settings.save('https://custom.example/path');
    expect(await settings.load(), 'https://custom.example/path');
  });
}
