import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/app/auth/auth_exceptions.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

import '../use_case.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('failed login restores the button and allows retry', (WidgetTester tester) async {
      final useCase = UseCase(tester);
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

      await useCase.tapLoginButton();

      expect(loginCalls, equals(1));
      expect(useCase.loginButton.enabled, isFalse);

      await useCase.tapLoginButton();

      expect(loginCalls, equals(1)); // still 1

      attempt.completeError(Exception('Login rejected'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(useCase.loginButton.enabled, isTrue);

      attempt = Completer<void>();

      await useCase.tapLoginButton();

      expect(loginCalls, equals(2));
      expect(useCase.loginButton.enabled, isFalse);

      attempt.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(useCase.loginButton.enabled, isTrue);
    });

    testWidgets('cancelled login enables retry without showing an error', (
      WidgetTester tester,
    ) async {
      final useCase = UseCase(tester);
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

      await useCase.tapLoginButton();

      attempt.completeError(UserCancelledException('User cancelled'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(useCase.loginButton.enabled, isTrue);

      attempt = Completer<void>();

      await useCase.tapLoginButton();

      expect(loginCalls, equals(2));

      attempt.complete();
      await tester.pumpAndSettle();
    });
  });
}
