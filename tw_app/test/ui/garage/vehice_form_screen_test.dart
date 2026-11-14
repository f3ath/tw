import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

import '../../robots.dart';

void main() {
  group('VehicleFormScreen', () {
    group('New Vehicle', () {
      testWidgets('distance units are selectable', (WidgetTester tester) async {
        final form = VehicleFormRobot(tester);
        await tester.pumpWidget(MaterialApp(home: VehicleFormScreen(repo: InMemoryVehicleRepo())));

        expect(form.selectedDistanceUnit, equals(DistanceUnit.mi));

        await form.selectDistanceUnit('km');

        expect(form.selectedDistanceUnit, equals(DistanceUnit.km));
      });

      testWidgets('manufacture date is selectable', (WidgetTester tester) async {
        final form = VehicleFormRobot(tester);
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: InMemoryVehicleRepo()),
          ),
        );

        expect(form.selectedDate, isNull);

        await form.selectDayAndConfirm('13');
        expect(form.selectedDate, equals(DateTime(2009, 10, 13)));

        await form.selectDayAndCancel('22');
        expect(form.selectedDate, equals(DateTime(2009, 10, 13))); // not changed
      });

      testWidgets('empty name is not allowed', (WidgetTester tester) async {
        final form = VehicleFormRobot(tester);
        final repo = InMemoryVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );
        await form.saveForm(pump: .settle);

        expect(repo.vehicles, isEmpty);
        expect(form.nameError, isNotEmpty);
        expect(form.dateError, isNotEmpty);

        await form.enterName('  ');
        await form.saveForm(pump: .settle);

        expect(repo.vehicles, isEmpty);
        expect(form.nameError, isNotEmpty);
        expect(form.dateError, isNotEmpty);
      });

      testWidgets('shows snackbar on error', (WidgetTester tester) async {
        final form = VehicleFormRobot(tester);
        final repo = InMemoryVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );
        final completer = repo.pauseNextCreate();
        await form.enterName('   Ford T');
        await form.selectDayAndConfirm('13');
        await form.selectDistanceUnit('km');
        await form.saveForm();

        expect(form.nameError, isNull);
        expect(form.dateError, isNull);
        expect(form.saveButton.enabled, isFalse);

        completer.completeError(Exception('Network error'));
        await tester.pump();
        expect(find.byKey(VehicleFormScreen.errorSnackBarKey), findsOneWidget);
        expect(form.saveButton.enabled, isTrue);
      });
    });
    group('Editing', () {
      testWidgets('shows loaded vehicle properties', (WidgetTester tester) async {
        final vehicle = Vehicle(
          'veh-id',
          name: 'Suzuki Grand Vitara',
          manufactureDate: DateTime(2005, 02, 03),
          distanceUnit: .km,
        );
        final form = VehicleFormRobot(tester);
        final repo = InMemoryVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo, vehicle: vehicle),
          ),
        );
        expect(form.selectedDate, equals(vehicle.manufactureDate));
        expect(form.selectedDistanceUnit, equals(vehicle.distanceUnit));
        expect(form.nameField.value, equals(vehicle.name));
      });
    });
  });
}

class ClockMock extends Mock implements Clock;
