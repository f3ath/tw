import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:app/app/auth_service.dart';
import 'package:app/app/app.dart';
import 'package:app/testing/stub.dart';
import 'package:app/testing/samples.dart' as samples;

import '../robots.dart';

void main() {
  group('TwApp', () {
    testWidgets('uses the dark brand theme on a device set to light mode', (tester) async {
      final dispatcher = tester.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        TwApp(
          authService: InMemoryAuthService(user: samples.sampleUser),
          vehicleRepo: InMemoryVehicleRepo(),
          scheduleRepo: InMemoryScheduleRepo(),
          serviceRepo: InMemoryServiceRepo(),
          operationRepo: InMemoryOperationRepo(),
        ),
      );
      await tester.pumpAndSettle();

      final scheme = Theme.of(tester.element(findWelcomeScreen)).colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, const Color(0xFF143338));
      expect(scheme.primary, const Color(0xFFDAEF91));
    });

    _testSessionFlows();
    _testOperationRepository();
  });
}

void _testSessionFlows() {
  testWidgets('opens the garage when startup restores a user', (tester) async {
    final restoredUser = Completer<User?>();
    await tester.pumpWidget(
      TwApp(
        authService: AuthServiceMock()..restoredUser = restoredUser.future,
        vehicleRepo: InMemoryVehicleRepo(),
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: InMemoryServiceRepo(),
        operationRepo: InMemoryOperationRepo(),
      ),
    );

    expect(findWelcomeScreen, findsNothing);
    expect(findGarageScreen, findsNothing);

    restoredUser.complete(samples.sampleUser);
    await tester.pumpAndSettle();

    expect(GarageRobot(tester).userNameText.data, samples.sampleUser.name);
  });

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
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: InMemoryServiceRepo(),
        operationRepo: InMemoryOperationRepo(),
      ),
    );

    await tester.pumpAndSettle();
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
}

void _testOperationRepository() {
  testWidgets('passes the operation repository from login through garage and service history', (
    tester,
  ) async {
    final vehicleRepo = InMemoryVehicleRepo(initialVehicles: samples.sampleVehicles);
    final serviceRepo = InMemoryServiceRepo(initialServices: samples.sampleServices);
    final operationRepo = InMemoryOperationRepo(initialOperations: samples.sampleOperations);
    final welcome = WelcomeRobot(tester);
    final garage = GarageRobot(tester);
    final services = ServiceRobot(tester);
    final operations = OperationRobot(tester);
    await tester.pumpWidget(
      TwApp(
        authService: InMemoryAuthService(user: samples.sampleUser),
        vehicleRepo: vehicleRepo,
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: serviceRepo,
        operationRepo: operationRepo,
      ),
    );
    await tester.pumpAndSettle();
    await welcome.tapLoginButton(pump: .settle);
    await garage.tapVehicleMenuServices(samples.fourRunner.id);

    await services.tapServiceCard(samples.fourRunnerTireService.id);

    expect(findOperationScreen, findsOneWidget);
    expect(operations.vehicleNameText.data, equals(samples.fourRunner.name));
    final localizations = MaterialLocalizations.of(tester.element(operations.findServiceDateText));
    expect(
      operations.serviceDateText.data,
      contains(localizations.formatShortDate(samples.fourRunnerTireService.date.toLocalDateTime())),
    );
    expect(operations.findOperationCard(samples.tireRotationOperation.id), findsOneWidget);
    expect(operations.findOperationCard(samples.oilChangeOperation.id), findsNothing);
    expect(operationRepo.listCalls, equals(1));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(findServiceScreen, findsOneWidget);
    expect(serviceRepo.listCalls, equals(1));
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(findGarageScreen, findsOneWidget);
    expect(vehicleRepo.listCalls, equals(1));
  });
}

class AuthServiceMock() implements AuthService {
  Future<User> loginResult = Future.value(User('id', name: 'name', email: 'email'));
  Future<User?> restoredUser = Future.value();

  @override
  Future<User?> restoreSession() => restoredUser;

  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 2),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => loginResult;

  @override
  Future<void> logout() async {}
}
