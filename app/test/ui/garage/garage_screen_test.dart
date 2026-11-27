import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';
import 'package:app/testing/stub.dart' as stub;
import 'package:app/testing/samples.dart' as samples;
import 'package:app/ui/garage/garage_screen.dart';
import 'package:app/ui/delete_confirmation_dialog.dart';
import 'package:app/ui/garage/vehicle_form_screen.dart';

import '../../robots.dart';

void main() {
  group('GarageScreen', () {
    testWidgets('shows vehicle age using the injected clock', (tester) async {
      final vehicle = Vehicle(
        'vehicle-id',
        name: 'Civic',
        manufactureDate: CalendarDate(2008, 10, 15),
        mileageUnit: .mi,
      );

      await Harness(initialVehicles: [vehicle]).pumpLoadedScreen(tester);

      expect(find.text('1 yr 0 mon old'), findsOneWidget);
    });

    testWidgets('shows overdue and due-soon schedules on the matching vehicle card', (
      tester,
    ) async {
      final vehicle = Vehicle(
        'vehicle-id',
        name: 'Civic',
        manufactureDate: CalendarDate(2008),
        mileageUnit: .km,
        odometer: Odometer(date: CalendarDate(2009, 10, 14), value: 20000),
      );
      final harness = Harness(initialVehicles: [vehicle, samples.santaFe]);
      harness.scheduleRepo.schedules.addAll({
        'brakes': Schedule(
          id: 'brakes',
          vehicleId: vehicle.id,
          name: 'Brakes',
          intervalDistance: null,
          intervalMonths: 6,
          details: 'Check the pads',
          nextDue: (date: CalendarDate(2009, 10, 16), odometer: null),
        ),
        'oil': Schedule(
          id: 'oil',
          vehicleId: vehicle.id,
          name: 'Oil change',
          intervalDistance: 5000,
          intervalMonths: null,
          details: 'Replace the filter',
          nextDue: (date: null, odometer: 19800),
        ),
      });

      await harness.pumpLoadedScreen(tester);

      final card = GarageRobot(tester).findVehicleCard(vehicle.id);
      final overdue = find.descendant(
        of: card,
        matching: find.text('Oil change — overdue by 200 km'),
      );
      final soon = find.descendant(of: card, matching: find.text('Brakes — due in 1 day'));
      expect(overdue, findsOneWidget);
      expect(soon, findsOneWidget);
      expect(tester.getTopLeft(overdue).dy, lessThan(tester.getTopLeft(soon).dy));
      expect(find.text('Check the pads'), findsNothing);
      expect(find.text('Replace the filter'), findsNothing);
    });

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
        await GarageRobot(tester).tapRetry();

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
        await garage.tapNewVehicle();

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
        await garage.tapNewVehicle();
        await form.enterName('New Car');
        await form.selectMileageUnit('km');
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

      testWidgets('a conflict after a lost response keeps the draft and refreshes the garage', (
        tester,
      ) async {
        final harness = Harness(initialVehicles: []);
        await harness.pumpLoadedScreen(tester);
        await GarageRobot(tester).tapNewVehicle();
        final form = VehicleFormRobot(tester);
        await form.enterName('New Car');
        await form.selectDayAndConfirm('2');
        final pending = harness.repo.pauseNextCreate();
        await form.saveForm();

        final id = harness.repo.createIds.single;
        final saved = Vehicle(
          id,
          name: 'New Car',
          manufactureDate: CalendarDate(2009, 10, 2),
          mileageUnit: .mi,
        );
        harness.repo.vehicles[id] = saved;
        pending.completeError(Exception('Response lost'));
        await tester.pumpAndSettle();
        expect(harness.repo.listCalls, 1);

        await form.saveForm(pump: .settle);

        expect(findVehicleFormScreen, findsOneWidget);
        expect(find.byKey(VehicleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(
          find.text('This vehicle ID already exists. Go back to check the garage.'),
          findsOneWidget,
        );
        expect(form.name, 'New Car');
        expect(form.saveButton.enabled, isTrue);
        expect(harness.repo.createIds, [id, id]);
        expect(harness.repo.listCalls, 2);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expectVehiclesVisible([saved]);
        expect(harness.repo.listCalls, 2);
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

    group('Manage services', () {
      testWidgets('editing a service refreshes the odometer used by due schedules', (tester) async {
        final date = CalendarDate(2009, 10, 14);
        Vehicle vehicleWithReading(int value) => Vehicle(
          'vehicle-id',
          name: 'Civic',
          manufactureDate: CalendarDate(2008),
          mileageUnit: .km,
          odometer: Odometer(date: date, value: value),
        );
        final vehicle = vehicleWithReading(20000);
        final harness = Harness(initialVehicles: [vehicle]);
        final service = Service(
          'service-id',
          vehicleId: vehicle.id,
          date: date,
          odometer: 20000,
          details: '',
        );
        harness.serviceRepo.services[service.id] = service;
        harness.scheduleRepo.schedules['oil'] = Schedule(
          id: 'oil',
          vehicleId: vehicle.id,
          name: 'Oil change',
          intervalDistance: 5000,
          intervalMonths: null,
          details: '',
          nextDue: (date: null, odometer: 20200),
        );

        await harness.pumpLoadedScreen(tester);
        expect(find.text('Oil change — due in 200 km'), findsOneWidget);

        await GarageRobot(tester).tapVehicleMenuServices(vehicle.id);
        await ServiceRobot(tester).tapServiceMenuEdit(service.id);
        final form = ServiceFormRobot(tester);
        await form.enterOdometer('20300');
        await form.saveForm(pump: .settle);
        harness.repo.vehicles[vehicle.id] = vehicleWithReading(20300);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Oil change — due in 200 km'), findsNothing);
        expect(find.text('Oil change — overdue by 100 km'), findsOneWidget);
      });

      for (final service in samples.sampleServices) {
        testWidgets('opens ${service.vehicleId} services and returns without reloading', (
          tester,
        ) async {
          final harness = Harness();
          final garage = GarageRobot(tester);
          final services = ServiceRobot(tester);
          final vehicle = harness.repo.vehicles[service.vehicleId]!;
          harness.serviceRepo.services.addAll({
            for (final sample in samples.sampleServices) sample.id: sample,
          });
          await harness.pumpLoadedScreen(tester);

          await garage.tapVehicleMenuServices(vehicle.id);

          expect(findServiceScreen, findsOneWidget);
          expect(findGarageScreen, findsNothing);
          expect(find.text(vehicle.name), findsOneWidget);
          expect(find.byIcon(Icons.build_outlined), findsOneWidget);
          expect(services.findServiceCard(service.id), findsOneWidget);
          for (final other in samples.sampleServices.where((s) => s.vehicleId != vehicle.id)) {
            expect(services.findServiceCard(other.id), findsNothing);
          }
          expect(harness.serviceRepo.listCalls, equals(1));

          await tester.pageBack();
          await tester.pumpAndSettle();

          expect(findServiceScreen, findsNothing);
          expect(findGarageScreen, findsOneWidget);
          expectVehiclesVisible([samples.santaFe, samples.fourRunner]);
          expect(harness.repo.listCalls, equals(1));
        });
      }
    });

    group('New Service shortcut', () {
      for (final vehicle in samples.sampleVehicles) {
        testWidgets('opens the ${vehicle.name} form and Back preserves the garage', (tester) async {
          final harness = Harness();
          final garage = GarageRobot(tester);
          final form = ServiceFormRobot(tester);
          await harness.pumpLoadedScreen(tester);

          await garage.tapVehicleNewService(vehicle.id);

          expect(findServiceFormScreen, findsOneWidget);
          expect(findGarageScreen, findsNothing);
          expect(findServiceScreen, findsNothing);
          expect(find.text(vehicle.name), findsOneWidget);
          expect(form.mileageUnitLabel, equals(vehicle.mileageUnit.name));
          expect(form.selectedDate, equals(CalendarDate.today(now: harness.now)));
          expect(form.odometer, isEmpty);
          await form.enterOdometer('12345');

          await tester.pageBack();
          await tester.pumpAndSettle();

          expect(findServiceFormScreen, findsNothing);
          expect(findGarageScreen, findsOneWidget);
          expectVehiclesVisible(samples.sampleVehicles);
          expect(harness.repo.listCalls, equals(1));
          expect(harness.serviceRepo.services, isEmpty);
          expect(harness.serviceRepo.listCalls, equals(0));
          expect(harness.operationRepo.listCalls, equals(0));
        });

        testWidgets('saves a new service for ${vehicle.name} and opens its operations', (
          tester,
        ) async {
          final harness = Harness();
          final garage = GarageRobot(tester);
          final form = ServiceFormRobot(tester);
          final services = ServiceRobot(tester);
          final operations = OperationRobot(tester);
          await harness.pumpLoadedScreen(tester);
          await garage.tapVehicleNewService(vehicle.id);
          await form.enterOdometer('12345');
          await form.enterDetails('  Shortcut service  ');

          await form.saveForm(pump: .settle);

          expect(findServiceFormScreen, findsNothing);
          expect(findGarageScreen, findsNothing);
          expect(findOperationScreen, findsOneWidget);
          expect(harness.repo.listCalls, equals(1));
          final created = harness.serviceRepo.services.values.single;
          expect(created.vehicleId, equals(vehicle.id));
          expect(created.date, equals(CalendarDate.today(now: harness.now)));
          expect(created.odometer, equals(12345));
          expect(created.details, equals('Shortcut service'));
          expect(operations.selectedService, same(created));
          expect(operations.vehicleNameText.data, equals(vehicle.name));
          expect(harness.operationRepo.listCalls, equals(1));
          expect(harness.serviceRepo.listCalls, equals(0));

          await tester.pageBack();
          await tester.pumpAndSettle();

          expect(findOperationScreen, findsNothing);
          expect(findServiceFormScreen, findsNothing);
          expect(findGarageScreen, findsOneWidget);
          expectVehiclesVisible(samples.sampleVehicles);
          expect(harness.repo.listCalls, equals(2));

          await garage.tapVehicleMenuServices(vehicle.id);

          expect(findServiceScreen, findsOneWidget);
          expect(services.findServiceCard(created.id), findsOneWidget);
          expect(find.text('Shortcut service'), findsOneWidget);
        });
      }

      testWidgets('failed shortcut save stays on the form and retry opens operations', (
        tester,
      ) async {
        final harness = Harness();
        final garage = GarageRobot(tester);
        final form = ServiceFormRobot(tester);
        final operations = OperationRobot(tester);
        await harness.pumpLoadedScreen(tester);
        await garage.tapVehicleNewService(samples.fourRunner.id);
        await form.enterOdometer('42');
        final pending = harness.serviceRepo.pauseNextCreate();

        await form.saveForm();

        expect(findServiceFormScreen, findsOneWidget);
        expect(findOperationScreen, findsNothing);
        expect(harness.operationRepo.listCalls, equals(0));
        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(form.findSaveError, findsOneWidget);
        expect(findServiceFormScreen, findsOneWidget);
        expect(findOperationScreen, findsNothing);
        expect(harness.operationRepo.listCalls, equals(0));

        await form.saveForm(pump: .settle);

        expect(findServiceFormScreen, findsNothing);
        expect(findOperationScreen, findsOneWidget);
        expect(operations.selectedService, same(harness.serviceRepo.services.values.single));
        expect(operations.vehicleNameText.data, equals(samples.fourRunner.name));
        expect(harness.repo.listCalls, equals(1));
      });
    });

    testWidgets('a service shortcut conflict can open fresh history without losing the draft', (
      tester,
    ) async {
      final harness = Harness();
      final vehicle = samples.fourRunner;
      final form = ServiceFormRobot(tester);
      await harness.pumpLoadedScreen(tester);
      await GarageRobot(tester).tapVehicleNewService(vehicle.id);
      await form.enterOdometer('42');
      final pending = harness.serviceRepo.pauseNextCreate();
      await form.saveForm();

      final id = harness.serviceRepo.createIds.single;
      harness.serviceRepo.services[id] = Service(
        id,
        vehicleId: vehicle.id,
        date: CalendarDate.today(now: harness.now),
        odometer: 42,
        details: 'Saved service',
      );
      pending.completeError(Exception('Response lost'));
      await tester.pumpAndSettle();
      await form.saveForm(pump: .settle);

      expect(findServiceFormScreen, findsOneWidget);
      expect(findOperationScreen, findsNothing);
      expect(harness.serviceRepo.createIds, [id, id]);
      expect(harness.serviceRepo.listCalls, 0);

      await tester.tap(find.text('View history'));
      await tester.pumpAndSettle();

      expect(findServiceScreen, findsOneWidget);
      expect(ServiceRobot(tester).findServiceCard(id), findsOneWidget);
      expect(harness.serviceRepo.listCalls, 1);
      expect(harness.operationRepo.listCalls, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(findServiceFormScreen, findsOneWidget);
      expect(form.odometer, '42');
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
        expect(find.byKey(DeleteConfirmationDialog.confirmationKey), findsNothing);
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
        expect(find.byKey(DeleteConfirmationDialog.confirmationKey), findsNothing);
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

class Harness({Iterable<Vehicle>? initialVehicles}) {
  final repo = stub.InMemoryVehicleRepo(
    initialVehicles: initialVehicles ?? [samples.santaFe, samples.fourRunner],
  );
  final scheduleRepo = stub.InMemoryScheduleRepo();
  final serviceRepo = stub.InMemoryServiceRepo();
  final operationRepo = stub.InMemoryOperationRepo();
  DateTime now() => DateTime(2009, 10, 15);

  Future<void> pumpLoadedScreen(WidgetTester tester, {String userName = 'John Doe'}) async {
    await pumpScreen(tester, userName: userName);
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester, {String userName = 'John Doe'}) async {
    await tester.pumpWidget(
      RepositoryProvider(
        vehicleRepo: repo,
        scheduleRepo: scheduleRepo,
        serviceRepo: serviceRepo,
        operationRepo: operationRepo,
        child: MaterialApp(
          home: GarageScreen(onLogout: () async {}, userName: userName, now: now),
        ),
      ),
    );
  }
}
