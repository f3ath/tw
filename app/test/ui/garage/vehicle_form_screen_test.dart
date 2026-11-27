import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';
import 'package:shared/resource_id.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart';
import 'package:app/ui/garage/vehicle_form_screen.dart';

import '../../robots.dart';

void main() {
  group('VehicleFormScreen', () {
    testWidgets('can scroll to Save in a short viewport', (tester) async {
      tester.view.physicalSize = const Size(400, 250);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = Harness();
      await harness.pumpForm(tester);

      final save = find.byKey(VehicleFormScreen.saveButtonKey);
      await tester.scrollUntilVisible(
        save,
        100,
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();

      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('Creation', () {
      testWidgets('mileage units are selectable', (tester) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        expect(form.selectedMileageUnit, equals(MileageUnit.mi));

        await form.selectMileageUnit('km');

        expect(form.selectedMileageUnit, equals(MileageUnit.km));
      });

      testWidgets('manufacture date can be selected and a subsequent change cancelled', (
        tester,
      ) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        expect(form.selectedDate, isNull);

        await form.selectDayAndConfirm('13');
        expect(form.selectedDate, equals(CalendarDate(2009, 10, 13)));

        await form.selectDayAndCancel('22');
        expect(form.selectedDate, equals(CalendarDate(2009, 10, 13)));
      });

      group('Validation', () {
        for (final scenario in [(name: 'empty', value: ''), (name: 'whitespace', value: '  ')]) {
          testWidgets('rejects a ${scenario.name} name with an otherwise valid date', (
            tester,
          ) async {
            final harness = Harness();
            final form = VehicleFormRobot(tester);
            await harness.pumpForm(tester);
            await form.enterName(scenario.value);
            await form.selectDayAndConfirm('13');

            await form.saveForm();

            expect(form.nameError, isNotEmpty);
            expect(form.dateError, isNull);
            expect(harness.repo.vehicles, isEmpty);
            expect(findVehicleFormScreen, findsOneWidget);
          });
        }

        testWidgets('requires a manufacture date', (tester) async {
          final harness = Harness();
          final form = VehicleFormRobot(tester);
          await harness.pumpForm(tester);
          await form.enterName('Ford T');

          await form.saveForm();

          expect(form.nameError, isNull);
          expect(form.dateError, isNotEmpty);
          expect(harness.repo.vehicles, isEmpty);
          expect(findVehicleFormScreen, findsOneWidget);
        });
      });

      testWidgets('saves trimmed name, date, and mileage unit and returns success', (tester) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('  Ford T  ');
        await form.selectDayAndConfirm('13');
        await form.selectMileageUnit('km');

        await form.saveForm(pump: .settle);

        expect(findVehicleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        final created = harness.repo.vehicles.values.single;
        expect(created.name, equals('Ford T'));
        expect(created.manufactureDate, equals(CalendarDate(2009, 10, 13)));
        expect(created.mileageUnit, equals(MileageUnit.km));
      });

      testWidgets('disables fields while saving, retains inputs after failure, and permits retry', (
        tester,
      ) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('   Ford T');
        await form.selectDayAndConfirm('13');
        await form.selectMileageUnit('km');
        final pending = harness.repo.pauseNextCreate();

        await form.saveForm();

        final draftId = harness.repo.createIds.single;
        expect(ResourceId.isValid(draftId), isTrue);
        expect(form.nameError, isNull);
        expect(form.dateError, isNull);
        expect(form.saveButton.enabled, isFalse);
        expect(tester.widget<TextFormField>(form.findNameField).enabled, isFalse);
        expect(
          tester.widget<DropdownButtonFormField<MileageUnit>>(form.findMileageUnitField).onChanged,
          isNull,
        );
        final dateInput = find.descendant(of: form.findDateField, matching: find.byType(TextField));
        expect(tester.widget<TextField>(dateInput).enabled, isFalse);
        await tester.tap(form.findDateField);
        await tester.pump();
        expect(form.findDatePickerDialog, findsNothing);
        await form.saveForm(pump: .none);
        expect(harness.repo.createIds, [draftId]);

        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(VehicleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
        expect(tester.widget<TextFormField>(form.findNameField).enabled, isTrue);
        expect(
          tester.widget<DropdownButtonFormField<MileageUnit>>(form.findMileageUnitField).onChanged,
          isNotNull,
        );
        expect(tester.widget<TextField>(dateInput).enabled, isTrue);
        expect(form.name, equals('   Ford T'));
        expect(form.selectedMileageUnit, equals(MileageUnit.km));
        expect(form.selectedDate, equals(CalendarDate(2009, 10, 13)));
        expect(harness.repo.vehicles, isEmpty);

        await form.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        expect(findVehicleFormScreen, findsNothing);
        expect(harness.repo.vehicles.values.single.name, equals('Ford T'));
        expect(harness.repo.createIds, [draftId, draftId]);
        expect(harness.repo.vehicles.keys.single, draftId);
      });
    });

    group('Editing', () {
      testWidgets('prefills properties and allows changing mileage units', (tester) async {
        final vehicle = samples.santaFe;
        final harness = Harness(vehicle: vehicle, initialVehicles: samples.sampleVehicles);
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);

        expect(form.selectedDate, equals(vehicle.manufactureDate));
        expect(form.selectedMileageUnit, equals(vehicle.mileageUnit));
        expect(form.name, equals(vehicle.name));
        expect(
          tester.widget<DropdownButtonFormField<MileageUnit>>(form.findMileageUnitField).onChanged,
          isNotNull,
        );
      });

      testWidgets('updates the original vehicle and returns success without creating another', (
        tester,
      ) async {
        final vehicle = samples.santaFe;
        final harness = Harness(vehicle: vehicle, initialVehicles: samples.sampleVehicles);
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('  Updated car  ');
        await form.selectMileageUnit('mi');
        await form.selectDayAndConfirm('13');
        final pending = harness.repo.pauseNextUpdate();

        await form.saveForm();
        expect(form.saveButton.enabled, isFalse);
        expect(harness.repo.vehicles[vehicle.id], same(vehicle));
        pending.complete();
        await tester.pumpAndSettle();

        expect(findVehicleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        expect(harness.repo.vehicles, hasLength(2));
        expect(harness.repo.createIds, isEmpty);
        final updated = harness.repo.vehicles[vehicle.id]!;
        expect(updated.id, equals(vehicle.id));
        expect(updated.name, equals('Updated car'));
        expect(updated.manufactureDate, equals(CalendarDate(2013, 1, 13)));
        expect(updated.mileageUnit, equals(MileageUnit.mi));
        expect(harness.repo.vehicles[samples.fourRunner.id], same(samples.fourRunner));
      });

      testWidgets('failed update retains edits and permits retry', (tester) async {
        final vehicle = samples.santaFe;
        final harness = Harness(vehicle: vehicle, initialVehicles: samples.sampleVehicles);
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('Updated car');
        await form.selectDayAndConfirm('13');
        final pending = harness.repo.pauseNextUpdate();
        await form.saveForm();
        expect(form.saveButton.enabled, isFalse);

        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(VehicleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
        expect(form.name, equals('Updated car'));
        expect(form.selectedDate, equals(CalendarDate(2013, 1, 13)));
        expect(form.selectedMileageUnit, equals(vehicle.mileageUnit));
        expect(harness.repo.vehicles[vehicle.id], same(vehicle));

        await form.saveForm(pump: .settle);

        expect(findVehicleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        expect(harness.repo.vehicles, hasLength(2));
        expect(harness.repo.vehicles[vehicle.id]!.name, equals('Updated car'));
      });
    });
  });
}

class Harness({final Vehicle? vehicle, Iterable<Vehicle> initialVehicles = const []}) {
  final repo = InMemoryVehicleRepo(initialVehicles: initialVehicles);
  DateTime now() => DateTime(2009, 10, 15);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider(
        vehicleRepo: repo,
        scheduleRepo: InMemoryScheduleRepo(),
        serviceRepo: InMemoryServiceRepo(),
        operationRepo: InMemoryOperationRepo(),
        child: MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()),
      ),
    );
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(vehicle: vehicle, now: now),
      ),
    );
    await tester.pumpAndSettle();
  }
}
