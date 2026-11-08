import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/testing/fake.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

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
      final repo = FakeVehicleRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'First', repo: repo),
        ),
      );
      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();
      expect(repo.listCalls, equals(1));
      expect(tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data, equals('First'));
      expectVehiclesLoaded();

      await tester.pumpWidget(
        MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: 'Second', repo: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data, equals('Second'));
      expectVehiclesLoaded();
      expect(repo.listCalls, equals(1));
    });

    testWidgets('Add button opens the form', (WidgetTester tester) async {
      final repo = await setUpTestHarness(tester);
      repo.listCompleter.complete(stub.vehicles);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GarageScreen.addButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsOne);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(VehicleFormScreen), findsNothing);
      expect(find.byType(GarageScreen), findsOne);
      expectVehiclesLoaded();
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
    expect(tester.widget<Text>(find.byKey(GarageScreen.userNameTextKey)).data, equals('Begelme'));

void expectVehiclesLoaded() {
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.textContaining('Nothing'), findsNothing);
  expect(find.text(stub.vehicle1.name), findsOne);
  expect(find.text(stub.vehicle2.name), findsOne);
}
