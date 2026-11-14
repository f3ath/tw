import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';

import '../../robots.dart';

void main() {
  group('GarageScreen', () {
    testWidgets('displays the user name and updates it on rebuild', (WidgetTester tester) async {
      final harness = Harness();
      await harness.pumpLoadedScreen(tester, userName: 'First');

      expectUserName(tester, 'First');

      await harness.pumpLoadedScreen(tester, userName: 'Second');

      expectUserName(tester, 'Second');
    });

    group('Loading', () {
      testWidgets('shows an empty state when no vehicles exist', (WidgetTester tester) async {
        final harness = Harness(initialVehicles: []);
        final completer = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsOne);

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsOne);
      });

      testWidgets('shows vehicles after loading completes', (WidgetTester tester) async {
        final harness = Harness();
        final completer = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsOne);

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
      });

      testWidgets('failed loading can be retried', (WidgetTester tester) async {
        final harness = Harness();
        var completer = harness.repo.pauseNextList();
        await harness.pumpScreen(tester);

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsOne);

        completer.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(GarageScreen.errorTextKey), findsOneWidget);

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);

        completer = harness.repo.pauseNextList();
        await tester.tap(find.byKey(GarageScreen.retryButtonKey));
        await tester.pump();

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsOne);

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
      });

      testWidgets('rebuilding does not reload vehicles', (WidgetTester tester) async {
        final harness = Harness();
        await harness.pumpLoadedScreen(tester, userName: 'First');

        expect(harness.repo.listCalls, equals(1));
        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);

        await harness.pumpLoadedScreen(tester, userName: 'Second');

        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
        expect(harness.repo.listCalls, equals(1));
      });
    });

    group('Add a Vehicle', () {
      testWidgets('leaving the add form returns to the garage', (WidgetTester tester) async {
        final garage = GarageRobot(tester);
        final harness = Harness();
        await harness.pumpLoadedScreen(tester);
        await garage.tapAddNewVehicleButton(pump: .settle);

        expect(findVehicleFormScreen, findsOne);
        expect(findGarageScreen, findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findVehicleFormScreen, findsNothing);
        expect(findGarageScreen, findsOne);
        expect(harness.repo.listCalls, equals(1));
        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
      });

      testWidgets('saving a new vehicle refreshes the garage', (WidgetTester tester) async {
        final harness = Harness();
        await harness.pumpLoadedScreen(tester);

        expect(harness.repo.listCalls, equals(1));

        final garage = GarageRobot(tester);
        final form = VehicleFormRobot(tester);
        await garage.tapAddNewVehicleButton(pump: .settle);
        await form.enterName('New Car');
        await form.selectDistanceUnit('km');
        await form.selectDayAndConfirm('2');
        await form.saveForm(pump: .settle);

        expect(findGarageScreen, findsOne);
        expect(findVehicleFormScreen, findsNothing);
        expect(harness.repo.listCalls, equals(2));
        expect(find.byKey(GarageScreen.loadingIndicatorKey), findsNothing);
        expect(find.byKey(GarageScreen.emptyTextKey), findsNothing);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
        expect(find.text('New Car'), findsOne);
      });
    });

    group('Edit a Vehicle', () {
      testWidgets('saving edits updates the vehicle in the garage', (WidgetTester tester) async {
        final harness = Harness();
        final vehicle = harness.repo.vehicles.values.first;
        await harness.pumpLoadedScreen(tester);

        final garage = GarageRobot(tester);
        final form = VehicleFormRobot(tester);
        await garage.tapVehicleMenuEdit(vehicle.id);

        expect(findGarageScreen, findsNothing);
        expect(findVehicleFormScreen, findsOne);

        await form.enterName('New Name');
        await form.selectDayAndConfirm('13');
        await form.saveForm(pump: .settle);

        expect(harness.repo.vehicles[vehicle.id]?.name, equals('New Name'));
        expect(harness.repo.vehicles[vehicle.id]?.manufactureDate.day, equals(13));
        expect(findGarageScreen, findsOne);
        expect(findVehicleFormScreen, findsNothing);
        expect(find.text(vehicle.name), findsNothing);
        expect(find.text('New Name'), findsOne);
        expect(harness.repo.listCalls, equals(2));
      });
    });

    group('Manage schedules', () {
      testWidgets('opens schedules for the selected vehicle and returns without reloading', (
        WidgetTester tester,
      ) async {
        final harness = Harness();
        final garage = GarageRobot(tester);
        final vehicle = harness.repo.vehicles.values.last;
        harness.scheduleRepo.schedules.addAll({
          for (final schedule in samples.sampleSchedules) schedule.id: schedule,
        });
        await harness.pumpLoadedScreen(tester);

        await garage.tapVehicleMenuSchedules(vehicle.id);

        expect(findScheduleScreen, findsOneWidget);
        expect(findGarageScreen, findsNothing);
        expect(find.text(vehicle.name), findsOneWidget);
        expect(find.byIcon(Icons.event_repeat), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text(samples.tireRotation.name), findsOneWidget);
        expect(find.text(samples.oilChange.name), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(findScheduleScreen, findsNothing);
        expect(findGarageScreen, findsOneWidget);
        expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
        expect(harness.repo.listCalls, equals(1));
      });
    });

    group('Delete a Vehicle', () {
      testWidgets('cancelling deletion preserves the vehicle', (WidgetTester tester) async {
        final garage = GarageRobot(tester);
        final harness = Harness();
        final vehicle = harness.repo.vehicles.values.first;
        await harness.pumpLoadedScreen(tester);
        await garage.tapVehicleMenuDelete(vehicle.id);
        await garage.tapAlertDialogButton('Cancel');
        await tester.pumpAndSettle();

        expect(harness.repo.vehicles.containsKey(vehicle.id), isTrue);
        expect(garage.findVehicleCard(vehicle.id), findsOneWidget);
        expect(find.byKey(GarageScreen.deleteConfirmation), findsNothing);
      });

      testWidgets('confirming deletion removes the vehicle and refreshes the list', (
        WidgetTester tester,
      ) async {
        final garage = GarageRobot(tester);
        final harness = Harness();
        final vehicle = harness.repo.vehicles.values.first;
        await harness.pumpLoadedScreen(tester);

        expect(garage.findVehicleCard(vehicle.id), findsOneWidget);

        await garage.tapVehicleMenuDelete(vehicle.id);
        await garage.tapAlertDialogButton('Delete');
        await tester.pumpAndSettle();

        expect(harness.repo.vehicles.containsKey(vehicle.id), isFalse);
        expect(garage.findVehicleCard(vehicle.id), findsNothing);
        expect(find.byKey(GarageScreen.deleteConfirmation), findsNothing);
      });

      testWidgets('failed deletion shows feedback and preserves the vehicle', (
        WidgetTester tester,
      ) async {
        final garage = GarageRobot(tester);
        final harness = Harness();
        final vehicle = harness.repo.vehicles.values.first;
        final completer = harness.repo.pauseNextDelete();
        await harness.pumpScreen(tester);
        await tester.pumpAndSettle();
        await garage.tapVehicleMenuDelete(vehicle.id);
        await garage.tapAlertDialogButton('Delete');
        completer.completeError(Exception('Network error'));
        await tester.pump();

        expect(find.byKey(GarageScreen.deleteErrorSnackBarKey), findsOneWidget);

        await tester.pumpAndSettle();

        expect(harness.repo.vehicles.containsKey(vehicle.id), isTrue);
      });
    });
  });
}

void expectUserName(WidgetTester tester, String name) =>
    expect(GarageRobot(tester).userNameText.data, equals(name));

void expectVehiclesVisible(List<Vehicle> vehicles) {
  for (final vehicle in vehicles) {
    final card = find.byKey(GarageScreen.vehicleCardKey(vehicle.id));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(vehicle.name)), findsOneWidget);
  }
}

class ClockMock extends Mock implements Clock;

class Harness({Iterable<Vehicle>? initialVehicles}) {
  final repo = stub.InMemoryVehicleRepo(
    initialVehicles: initialVehicles ?? [samples.santaFe, samples.fourRunner],
  );
  final scheduleRepo = stub.InMemoryScheduleRepo();
  final clock = ClockMock();

  this {
    when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
  }

  Future<void> pumpLoadedScreen(WidgetTester tester, {String userName = 'John Doe'}) async {
    await pumpScreen(tester, userName: userName);
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester, {String userName = 'John Doe'}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GarageScreen(
          onLogout: () async {},
          userName: userName,
          repo: repo,
          scheduleRepo: scheduleRepo,
          clock: clock,
        ),
      ),
    );
  }
}
