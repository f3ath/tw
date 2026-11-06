import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/domain/user.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

void main() {
  testWidgets('Login opens Garage, Logout returns to Welcome', (WidgetTester tester) async {
    final findWelcomeScreen = find.byType(WelcomeScreen);
    final findGarageScreen = find.byType(GarageScreen);
    final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);
    final findLogoutButton = find.byKey(GarageScreen.logoutButtonKey);

    final authResult = Completer<User>();
    final authService = AuthServiceStub();
    authService.loginResult = authResult.future;

    await tester.pumpWidget(TwApp(authService: authService));

    expect(findWelcomeScreen, findsOneWidget);
    expect(findGarageScreen, findsNothing);

    expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNotNull);

    await tester.tap(findLoginButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNull);

    authResult.complete(User('id', name: 'name', email: 'email'));

    await tester.pumpAndSettle();

    expect(findWelcomeScreen, findsNothing);
    expect(findGarageScreen, findsOneWidget);

    await tester.tap(findLogoutButton);
    await tester.pumpAndSettle();

    expect(findWelcomeScreen, findsOneWidget);
    expect(findGarageScreen, findsNothing);
  });
}

class AuthServiceStub() implements AuthServicePort {
  Future<User> loginResult = Future.value(User('id', name: 'name', email: 'email'));

  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => loginResult;

  @override
  Future<void> logout() async {}
}
