import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:tw_app/auth/login_control.dart';
import 'package:tw_app/auth/login_controller.dart';
import 'package:tw_shared/api.dart';

void main() {
  late List<http.Request> requests;
  late MockClient transport;
  late TwApiClient client;
  var pending = false;
  var failLogin = false;
  var failLogout = false;

  setUp(() {
    requests = [];
    pending = false;
    failLogin = false;
    failLogout = false;
    transport = MockClient((request) async {
      requests.add(request);
      if (request.method.toUpperCase() == 'POST') {
        if (failLogin) return http.Response('', 503);
        return http.Response(
          jsonEncode({
            'data': {
              'type': 'sessions',
              'id': 'session-1',
              'attributes': {
                'key': 'session-secret',
                'redirect': 'https://accounts.google.com/sign-in',
              },
            },
          }),
          201,
          headers: {'content-type': 'application/vnd.api+json'},
        );
      }
      if (request.method.toUpperCase() == 'DELETE') {
        return http.Response('', failLogout ? 503 : 204);
      }
      return http.Response(
        jsonEncode({
          'data': pending
              ? null
              : {
                  'type': 'users',
                  'id': 'user-1',
                  'attributes': {'name': 'Ada Lovelace', 'email': 'ada@example.com'},
                },
        }),
        200,
        headers: {'content-type': 'application/vnd.api+json'},
      );
    });
    client = TwApiClient(
      StandardUriDesign(Uri.parse('https://server.example/api/v0')),
      transport.handleInterop,
    );
  });

  tearDown(() => transport.close());

  Future<void> showControl(WidgetTester tester, {bool openBrowser = true}) async {
    final controller = LoginController(
      client: client,
      openAuthorization: (uri) async {
        expect(uri.host, 'accounts.google.com');
        return openBrowser;
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [LoginControl(controller: controller)]),
        ),
      ),
    );
    await tester.tap(find.text('Log in'));
    await tester.pump();
  }

  testWidgets('signs in, displays name, and revokes session on logout', (tester) async {
    await showControl(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(requests.last.url.path, '/api/v0/sessions/session-1/user');
    expect(requests.last.headers['authorization'], 'Bearer session-secret');

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(requests.last.method.toUpperCase(), 'DELETE');
    expect(requests.last.url.path, '/api/v0/sessions/session-1');
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('waits for OAuth and allows retrying a blocked browser', (tester) async {
    pending = true;
    await showControl(tester, openBrowser: false);
    expect(find.text('Open sign-in'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    pending = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('failed login allows retry', (tester) async {
    failLogin = true;
    await showControl(tester);
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Could not sign in. Please try again.'), findsOneWidget);
  });

  testWidgets('failed logout preserves account and allows retry', (tester) async {
    await showControl(tester);
    await tester.pumpAndSettle();
    failLogout = true;
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Could not log out. Please try again.'), findsOneWidget);
  });
}
