import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/app/auth/auth_exceptions.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

import '../robots.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('failed login restores the button and allows retry', (WidgetTester tester) async {
      final welcome = WelcomeRobot(tester);
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

      await welcome.tapLoginButton();

      expect(loginCalls, equals(1));
      expect(welcome.loginButton.enabled, isFalse);

      await welcome.tapLoginButton();

      expect(loginCalls, equals(1)); // still 1

      attempt.completeError(Exception('Login rejected'));
      await tester.pumpAndSettle();

      expect(find.byKey(WelcomeScreen.errorSnackBarKey), findsOneWidget);
      expect(welcome.loginButton.enabled, isTrue);

      attempt = Completer<void>();

      await welcome.tapLoginButton();

      expect(loginCalls, equals(2));
      expect(welcome.loginButton.enabled, isFalse);

      attempt.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(WelcomeScreen.errorSnackBarKey), findsNothing);
      expect(welcome.loginButton.enabled, isTrue);
    });

    testWidgets('cancelled login enables retry without showing an error', (
      WidgetTester tester,
    ) async {
      final welcome = WelcomeRobot(tester);
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

      await welcome.tapLoginButton();

      attempt.completeError(UserCancelledException('User cancelled'));
      await tester.pumpAndSettle();

      expect(find.byKey(WelcomeScreen.errorSnackBarKey), findsNothing);
      expect(welcome.loginButton.enabled, isTrue);

      attempt = Completer<void>();

      await welcome.tapLoginButton();

      expect(loginCalls, equals(2));

      attempt.complete();
      await tester.pumpAndSettle();
    });
  });
}
