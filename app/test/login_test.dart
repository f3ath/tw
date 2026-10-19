import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/auth/login_control.dart';
import 'package:app/auth/login_controller.dart';
import 'package:shared/api.dart';

import 'support/fake_tw_api_client.dart';

void main() {
  late FakeTwApiClient client;
  late List<Uri> openedAuthorizations;

  setUp(() {
    client = FakeTwApiClient()
      ..user = const User(id: 'user-1', name: 'Ada Lovelace', email: 'ada@example.com');
    openedAuthorizations = [];
  });

  Future<void> showControl(WidgetTester tester, {bool openBrowser = true}) async {
    final controller = LoginController(
      client: client,
      openAuthorization: (uri) async {
        openedAuthorizations.add(uri);
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
    expect(client.createCount, 1);

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(client.deleteCount, 1);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('waits for OAuth and allows retrying a blocked browser', (tester) async {
    client.pending = true;
    await showControl(tester, openBrowser: false);
    expect(find.text('Open sign-in'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(openedAuthorizations, hasLength(1));
    await tester.tap(find.text('Open sign-in'));
    await tester.pump();
    expect(openedAuthorizations, hasLength(2));
    client.pending = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('failed login allows retry', (tester) async {
    client.failLogin = true;
    await showControl(tester);
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Could not sign in. Please try again.'), findsOneWidget);

    client.failLogin = false;
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('failed logout preserves account and allows retry', (tester) async {
    await showControl(tester);
    await tester.pumpAndSettle();
    client.failLogout = true;
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Could not log out. Please try again.'), findsOneWidget);

    client.failLogout = false;
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(client.deleteCount, 2);
  });
}
