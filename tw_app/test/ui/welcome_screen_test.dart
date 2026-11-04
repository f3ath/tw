import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

void main() {
  testWidgets('Failed login restores the button and allows retry', (WidgetTester tester) async {
    var attempt = Completer<void>();


    var loginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onLogin: () async {
            loginCalls++;
            await attempt.future;
          },
        ),
      ),
    );

    final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);
    await tester.tap(findLoginButton);
    await tester.pump();

    expect(loginCalls, equals(1));
    expect(tester.widget<FilledButton>(findLoginButton).enabled, isFalse);

    await tester.tap(findLoginButton);
    await tester.pump();

    expect(loginCalls, equals(1)); // still 1

    attempt.completeError(Exception('Login rejected'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<FilledButton>(findLoginButton).enabled, isTrue);

    attempt = Completer<void>();

    await tester.tap(findLoginButton);
    await tester.pump();

    expect(loginCalls, equals(2));
    expect(tester.widget<FilledButton>(findLoginButton).enabled, isFalse);

    attempt.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.widget<FilledButton>(findLoginButton).enabled, isTrue);

  });
}
