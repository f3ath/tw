import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_api/document.dart';
import 'package:app/auth/login_controller.dart';
import 'package:app/auth/login_state.dart';
import 'package:shared/api.dart';

import 'support/fake_tw_api_client.dart';

void main() {
  late FakeTwApiClient client;
  late LoginController controller;

  setUp(() {
    client = FakeTwApiClient();
    controller = LoginController(client: client, openAuthorization: (_) async => true);
  });

  tearDown(() => controller.dispose());

  test('exposes login states and signs out after revoking the session', () async {
    final states = <LoginState>[];
    controller.addListener(() => states.add(controller.state));

    await controller.login();
    await controller.logout();

    expect(states, [
      isA<SigningIn>(),
      isA<AwaitingAuthorization>(),
      isA<SignedIn>().having((state) => state.userName, 'userName', 'Ada'),
      isA<SigningOut>(),
      isA<SignedOut>(),
    ]);
    expect(client.deleteCount, 1);
  });

  test('failed logout preserves the account and supports retry', () async {
    await controller.login();
    client.failLogout = true;
    await controller.logout();

    expect(controller.state, isA<SignedIn>());
    expect(controller.takeError(), 'Could not log out. Please try again.');
    expect(controller.takeError(), isNull);

    client.failLogout = false;
    await controller.logout();
    expect(controller.state, isA<SignedOut>());
  });

  test('uses email or a generic label when the user has no name', () async {
    client.user = const User(id: 'user-1', name: '  ', email: 'ada@example.com');
    await controller.login();
    expect((controller.state as SignedIn).userName, 'ada@example.com');

    await controller.logout();
    client.user = const User(id: 'user-1', name: '  ', email: '');
    await controller.login();
    expect((controller.state as SignedIn).userName, 'Signed in');
  });

  test('rejects an invalid authorization URL without opening a browser', () async {
    client.session.attributes['redirect'] = 'https:missing-host';
    await controller.login();

    expect(controller.state, isA<SignedOut>());
    expect(controller.takeError(), 'Could not sign in. Please try again.');
    expect(client.fetchCount, 0);
  });

  test('times out and allows a new attempt', () async {
    controller.dispose();
    var now = DateTime.utc(2026);
    client.onFetchUser = () async {
      now = now.add(const Duration(minutes: 4));
      return null;
    };
    controller = LoginController(
      client: client,
      openAuthorization: (_) async => true,
      clock: () => now,
    );

    await controller.login();
    expect(controller.state, isA<SignedOut>());
    expect(controller.takeError(), 'Sign-in timed out. Please try again.');
    expect(client.fetchCount, 1);

    client.onFetchUser = null;
    await controller.login();
    expect(controller.state, isA<SignedIn>());
  });

  test('cancelling a pending poll completes login without another request', () async {
    final fetched = Completer<void>();
    client.onFetchUser = () async {
      fetched.complete();
      return null;
    };
    final login = controller.login();
    await fetched.future;
    await Future<void>.delayed(Duration.zero);

    controller.cancelLogin();
    await login;

    expect(controller.state, isA<SignedOut>());
    expect(controller.takeError(), isNull);
    expect(client.fetchCount, 1);
  });

  test('disposal cancels a pending poll', () async {
    final fetched = Completer<void>();
    client.onFetchUser = () async {
      fetched.complete();
      return null;
    };
    final pendingController = LoginController(client: client, openAuthorization: (_) async => true);
    var notifications = 0;
    pendingController.addListener(() => notifications++);
    final login = pendingController.login();
    await fetched.future;
    await Future<void>.delayed(Duration.zero);

    pendingController.dispose();
    await login;

    expect(notifications, 2);
    expect(client.fetchCount, 1);
  });

  test('disposal ignores a session request that completes later', () async {
    final session = Completer<Resource?>();
    client.onCreateSession = () => session.future;
    var browserCalls = 0;
    final pendingController = LoginController(
      client: client,
      openAuthorization: (_) async {
        browserCalls++;
        return true;
      },
    );
    final login = pendingController.login();
    pendingController.dispose();
    session.complete(client.session);
    await login;

    expect(browserCalls, 0);
    expect(client.fetchCount, 0);
  });

  test('retry waits for a cancelled session request before creating another', () async {
    final firstSession = Completer<Resource?>();
    client.onCreateSession = () =>
        client.createCount == 1 ? firstSession.future : Future.value(client.session);
    final firstLogin = controller.login();
    controller.cancelLogin();
    final retry = controller.login();
    final requestsBeforeCompletion = client.createCount;

    firstSession.complete(client.session);
    await Future.wait([firstLogin, retry]);

    expect(requestsBeforeCompletion, 1);
    expect(client.createCount, 2);
    expect(controller.state, isA<SignedIn>());
  });
}
