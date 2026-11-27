import 'dart:convert';

import 'package:app/data/auth/api_client_adapter.dart';
import 'package:app/data/auth/backend_auth_service.dart';
import 'package:app/data/auth/login_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Map<String, String> stored;
  late SessionBackend backend;
  setUp(() {
    stored = {};
    backend = SessionBackend();
  });

  BackendAuthService openApp() {
    final baseUri = Uri.parse('https://example.test/api/v0');
    final httpClient = MockClient(backend.send);
    addTearDown(httpClient.close);
    final client = TwApiClient(StandardUriDesign(baseUri), httpClient.sendInterop);
    return BackendAuthService(
      authApi: ApiClientAdapter(client, preferences: PreferencesStub(stored), baseUri: baseUri),
      newWindow: LoginWindowStub.new,
    );
  }

  test('a completed login can be restored by a fresh app instance', () async {
    final user = await openApp().login();

    final restoredUser = await openApp().restoreSession();

    expect(restoredUser?.id, user.id);
  });

  test('a rejected session is discarded', () async {
    await openApp().login();
    backend.userStatus = 401;
    expect(await openApp().restoreSession(), isNull);

    backend.userStatus = 200;
    expect(await openApp().restoreSession(), isNull);
  });

  test('a temporary verification failure leaves the session available for retry', () async {
    await openApp().login();
    final restartedApp = openApp();
    backend.userStatus = 503;
    await expectLater(restartedApp.restoreSession(), throwsA(isA<RequestFailure>()));

    backend.userStatus = 200;
    expect(await restartedApp.restoreSession(), isNotNull);
  });

  test('logout clears the saved session even when revocation fails', () async {
    final app = openApp();
    await app.login();
    backend.revokeStatus = 503;
    await expectLater(app.logout(), throwsA(isA<RequestFailure>()));

    expect(await openApp().restoreSession(), isNull);
  });
}

class PreferencesStub(final Map<String, String> _stored)
    extends Fake
    implements SharedPreferencesAsync {
  @override
  Future<String?> getString(String key) async => _stored[key];

  @override
  Future<void> setString(String key, String value) async {
    _stored[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _stored.remove(key);
  }
}

class LoginWindowStub implements LoginWindow {
  @override
  bool get isClosed => false;

  @override
  Future<void> navigate(Uri uri) async {}

  @override
  void close() {}
}

class SessionBackend {
  int userStatus = 200;
  int revokeStatus = 204;

  Future<http.Response> send(http.Request request) async {
    if (request.method == 'POST' && request.url.path == '/api/v0/sessions') {
      return _resource(201, 'sessions', 'session-id', {
        'token': 'session-token',
        'redirect': 'https://example.test/oauth',
      });
    }
    expect(request.headers['authorization'], 'Bearer session-token');
    return switch ((request.method, request.url.path)) {
      ('GET', '/api/v0/sessions/current/user') =>
        userStatus == 200
            ? _resource(200, 'users', 'user-id', {
                'name': 'User Name',
                'email': 'user@example.test',
              })
            : http.Response('', userStatus),
      ('DELETE', '/api/v0/sessions/current') => http.Response('', revokeStatus),
      _ => throw StateError('Unexpected request ${request.method} ${request.url}'),
    };
  }

  http.Response _resource(int status, String type, String id, Map<String, String> attributes) =>
      http.Response(
        jsonEncode({
          'data': {'type': type, 'id': id, 'attributes': attributes},
        }),
        status,
        headers: {'content-type': 'application/vnd.api+json'},
      );
}
