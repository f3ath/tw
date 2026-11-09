import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/testing/fake.dart' as fake;
import 'package:tw_app/testing/stub.dart';

import '../use_case.dart';

void main() {
  group('TwApp', () {
    testWidgets('Login opens Garage, Logout returns to Welcome', (WidgetTester tester) async {
      final useCase = UseCase(tester);

      final authResult = Completer<User>();
      final authService = AuthServiceMock();
      authService.loginResult = authResult.future;

      final repo = fake.FakeVehicleRepo();
      repo.listCompleter.complete(vehicles);
      await tester.pumpWidget(TwApp(authService: authService, vehicleRepo: repo));

      expect(findWelcomeScreen, findsOneWidget);
      expect(findGarageScreen, findsNothing);

      expect(useCase.loginButton.onPressed, isNotNull);

      await useCase.tapLoginButton();

      expect(useCase.loginButton.onPressed, isNull);

      authResult.complete(User('id', name: 'User Name', email: 'email'));

      await tester.pumpAndSettle();

      expect(findWelcomeScreen, findsNothing);
      expect(findGarageScreen, findsOneWidget);
      expect(useCase.userNameText.data, equals('User Name'));

      await useCase.tapLogoutButton(settle:true);

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
