import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/testing/stub.dart';

import '../robots.dart';

void main() {
  group('TwApp', () {
    testWidgets('Login opens Garage, Logout returns to Welcome', (WidgetTester tester) async {
      final welcome = WelcomeRobot(tester);
      final garage = GarageRobot(tester);

      final authResult = Completer<User>();
      final authService = AuthServiceMock();
      authService.loginResult = authResult.future;

      await tester.pumpWidget(
        TwApp(
          authService: authService,
          vehicleRepo: InMemoryVehicleRepo(),
          schedulesRepo: InMemorySchedulesRepo(),
        ),
      );

      expect(findWelcomeScreen, findsOneWidget);
      expect(findGarageScreen, findsNothing);

      expect(welcome.loginButton.onPressed, isNotNull);

      await welcome.tapLoginButton();

      expect(welcome.loginButton.onPressed, isNull);

      authResult.complete(User('id', name: 'User Name', email: 'email'));

      await tester.pumpAndSettle();

      expect(findWelcomeScreen, findsNothing);
      expect(findGarageScreen, findsOneWidget);
      expect(garage.userNameText.data, equals('User Name'));

      await garage.tapLogoutButton(pump: .settle);

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
