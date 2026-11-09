import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tw_app/testing/fake.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';

import '../../use_case.dart';

void main() {
  group('GarageScreen', () {
    testWidgets('load and show empty', (WidgetTester tester) async {
      final repo = await setUpTestHarness(tester);

      expectUserNameIsShown(tester);

      repo.listCompleter.complete([]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing'), findsOne);
      expect(find.text(stub.vehicle1.name), findsNothing);
    });

    testWidgets('load and show vehicles', (WidgetTester tester) async {
      final repo = await setUpTestHarness(tester);

      expectUserNameIsShown(tester);
      expect(find.byType(CircularProgressIndicator), findsOne);
      expect(find.textContaining('Nothing'), findsNothing);

      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();

      expectVehiclesLoaded();
    });

    testWidgets('load, error, restart', (WidgetTester tester) async {
      final repo = await setUpTestHarness(tester);

      expectUserNameIsShown(tester);
      expect(find.byType(CircularProgressIndicator), findsOne);
      expect(find.textContaining('Nothing'), findsNothing);

      repo.listCompleter.completeError(Exception('Network error'));

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Nothing'), findsNothing);

      repo.reset();
      await tester.tap(find.byKey(GarageScreen.retryButtonKey));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOne);

      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();

      expectVehiclesLoaded();
    });

    testWidgets('repo is reused', (WidgetTester tester) async {
      final useCase = UseCase(tester);
      final repo = FakeVehicleRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'First', repo: repo),
        ),
      );
      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();
      expect(repo.listCalls, equals(1));
      expect(useCase.userNameText.data, equals('First'));
      expectVehiclesLoaded();

      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Second', repo: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(useCase.userNameText.data, equals('Second'));
      expectVehiclesLoaded();
      expect(repo.listCalls, equals(1));
    });

    testWidgets('open the form, navigate back', (WidgetTester tester) async {
      final useCase = GarageUC(tester);
      final repo = await setUpTestHarness(tester);
      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();
      await useCase.tapAddNewVehicleButton(settle: true);

      expect(findVehicleFormScreen, findsOne);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(findVehicleFormScreen, findsNothing);
      expect(findGarageScreen, findsOne);
      expectVehiclesLoaded();
    });

    testWidgets('open the form, add vehicle', (WidgetTester tester) async {
      final repo = FakeVehicleRepo();
      repo.listCompleter.complete(stub.vehicles);
      repo.createCompleter.complete();
      final clock = ClockMock();
      when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Begelme', repo: repo, clock: clock),
        ),
      );
      expect(repo.listCalls, equals(1));

      final uc = VehicleFormUC(tester);
      await uc.tapAddNewVehicleButton(settle: true);
      await uc.enterName('New Car');
      await uc.selectDistanceUnit('km');
      await uc.selectDayAndConfirm('2');
      await uc.saveForm(settle: true);

      expect(findGarageScreen, findsOne);
      expect(findVehicleFormScreen, findsNothing);
      expect(repo.listCalls, equals(2));
    });
  });
}

Future<FakeVehicleRepo> setUpTestHarness(WidgetTester tester) async {
  final repo = FakeVehicleRepo();
  await tester.pumpWidget(
    MaterialApp(
      home: GarageScreen(onLogout: () async {}, userName: 'Begelme', repo: repo),
    ),
  );
  return repo;
}

void expectUserNameIsShown(WidgetTester tester) =>
    expect(UseCase(tester).userNameText.data, equals('Begelme'));

void expectVehiclesLoaded() {
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.textContaining('Nothing'), findsNothing);
  expect(find.text(stub.vehicle1.name), findsOne);
  expect(find.text(stub.vehicle2.name), findsOne);
}

class ClockMock extends Mock implements Clock;
