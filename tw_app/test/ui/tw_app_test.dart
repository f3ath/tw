import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/fake.dart' as fake;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

void main() {
  group('TwApp', () {
    testWidgets('Login opens Garage, Logout returns to Welcome', (WidgetTester tester) async {
      final findWelcomeScreen = find.byType(WelcomeScreen);
      final findGarageScreen = find.byType(GarageScreen);
      final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);
      final findLogoutButton = find.byKey(GarageScreen.logoutButtonKey);

      final authResult = Completer<User>();
      final authService = AuthServiceMock();
      authService.loginResult = authResult.future;

      final repo = fake.FakeVehicleRepo();
      repo.listCompleter.complete(vehicles);
      await tester.pumpWidget(TwApp(authService: authService, vehicleRepo: repo));

      expect(findWelcomeScreen, findsOneWidget);
      expect(findGarageScreen, findsNothing);

      expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNotNull);

      await tester.tap(findLoginButton);
      await tester.pump();

      expect(tester.widget<FilledButton>(findLoginButton).onPressed, isNull);

      authResult.complete(User('id', name: 'User Name', email: 'email'));

      await tester.pumpAndSettle();

      expect(findWelcomeScreen, findsNothing);
      expect(findGarageScreen, findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data,
        equals('User Name'),
      );

      await tester.tap(findLogoutButton);
      await tester.pumpAndSettle();

      expect(findWelcomeScreen, findsOneWidget);
      expect(findGarageScreen, findsNothing);
    });
  });
}

class AuthServiceMock() implements AuthService {
  Future<User> loginResult = Future.value(User('id', name: 'name', email: 'email'));

  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => loginResult;

  @override
  Future<void> logout() async {}
}
