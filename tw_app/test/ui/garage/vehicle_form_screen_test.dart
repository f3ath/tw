import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tw_app/testing/fixed_clock.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/garage/vehicle_form_screen.dart';

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
      testWidgets('distance units are selectable', (tester) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        expect(form.selectedDistanceUnit, equals(DistanceUnit.mi));

        await form.selectDistanceUnit('km');

        expect(form.selectedDistanceUnit, equals(DistanceUnit.km));
      });

      testWidgets('manufacture date can be selected and a subsequent change cancelled', (
        tester,
      ) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        expect(form.selectedDate, isNull);

        await form.selectDayAndConfirm('13');
        expect(form.selectedDate, equals(DateTime(2009, 10, 13)));

        await form.selectDayAndCancel('22');
        expect(form.selectedDate, equals(DateTime(2009, 10, 13)));
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

      testWidgets('saves trimmed name, date, and distance unit and returns success', (
        tester,
      ) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('  Ford T  ');
        await form.selectDayAndConfirm('13');
        await form.selectDistanceUnit('km');

        await form.saveForm(pump: .settle);

        expect(findVehicleFormScreen, findsNothing);
        expect(await harness.result, isTrue);
        final created = harness.repo.vehicles.values.single;
        expect(created.name, equals('Ford T'));
        expect(created.manufactureDate, equals(DateTime(2009, 10, 13)));
        expect(created.distanceUnit, equals(DistanceUnit.km));
      });

      testWidgets('disables fields while saving, retains inputs after failure, and permits retry', (
        tester,
      ) async {
        final harness = Harness();
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);
        await form.enterName('   Ford T');
        await form.selectDayAndConfirm('13');
        await form.selectDistanceUnit('km');
        final pending = harness.repo.pauseNextCreate();

        await form.saveForm();

        expect(form.nameError, isNull);
        expect(form.dateError, isNull);
        expect(form.saveButton.enabled, isFalse);
        expect(tester.widget<TextFormField>(form.findNameField).enabled, isFalse);
        expect(
          tester
              .widget<DropdownButtonFormField<DistanceUnit>>(form.findDistanceUnitField)
              .onChanged,
          isNull,
        );
        final dateInput = find.descendant(of: form.findDateField, matching: find.byType(TextField));
        expect(tester.widget<TextField>(dateInput).enabled, isFalse);
        await tester.tap(form.findDateField);
        await tester.pump();
        expect(form.findDatePickerDialog, findsNothing);
        await form.saveForm(pump: .none);

        pending.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        expect(find.byKey(VehicleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
        expect(tester.widget<TextFormField>(form.findNameField).enabled, isTrue);
        expect(
          tester
              .widget<DropdownButtonFormField<DistanceUnit>>(form.findDistanceUnitField)
              .onChanged,
          isNotNull,
        );
        expect(tester.widget<TextField>(dateInput).enabled, isTrue);
        expect(form.name, equals('   Ford T'));
        expect(form.selectedDistanceUnit, equals(DistanceUnit.km));
        expect(form.selectedDate, equals(DateTime(2009, 10, 13)));
        expect(harness.repo.vehicles, isEmpty);

        await form.saveForm(pump: .settle);

        expect(await harness.result, isTrue);
        expect(findVehicleFormScreen, findsNothing);
        expect(harness.repo.vehicles.values.single.name, equals('Ford T'));
      });
    });

    group('Editing', () {
      testWidgets('prefills properties and locks distance units', (tester) async {
        final vehicle = samples.santaFe;
        final harness = Harness(vehicle: vehicle, initialVehicles: samples.sampleVehicles);
        final form = VehicleFormRobot(tester);
        await harness.pumpForm(tester);

        expect(form.selectedDate, equals(vehicle.manufactureDate));
        expect(form.selectedDistanceUnit, equals(vehicle.distanceUnit));
        expect(form.name, equals(vehicle.name));
        expect(
          tester
              .widget<DropdownButtonFormField<DistanceUnit>>(form.findDistanceUnitField)
              .onChanged,
          isNull,
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
        final updated = harness.repo.vehicles[vehicle.id]!;
        expect(updated.id, equals(vehicle.id));
        expect(updated.name, equals('Updated car'));
        expect(updated.manufactureDate, equals(DateTime(2013, 1, 13)));
        expect(updated.distanceUnit, equals(vehicle.distanceUnit));
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
        expect(form.selectedDate, equals(DateTime(2013, 1, 13)));
        expect(form.selectedDistanceUnit, equals(vehicle.distanceUnit));
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
  final clock = FixedClock(DateTime(2009, 10, 15));
  final _navigatorKey = GlobalKey<NavigatorState>();
  late Future<bool?> result;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: _navigatorKey, home: const Scaffold()));
    result = _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(vehicle: vehicle, repo: repo, clock: clock),
      ),
    );
    await tester.pumpAndSettle();
  }
}
