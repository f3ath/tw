import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

import '../../use_case.dart';

void main() {
  group('VehicleFormScreen', () {
    group('New Vehicle', () {
      testWidgets('distance units are selectable', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        await tester.pumpWidget(
            MaterialApp(home: VehicleFormScreen(repo: InMemoryVehicleRepo())));

        expect(uc.selectedDistanceUnit, equals(DistanceUnit.mi));

        await uc.selectDistanceUnit('km');

        expect(uc.selectedDistanceUnit, equals(DistanceUnit.km));
      });

      testWidgets(
          'manufacture date is selectable', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: InMemoryVehicleRepo()),
          ),
        );

        expect(uc.selectedDate, isNull);

        await uc.selectDayAndConfirm('13');
        expect(uc.selectedDate, equals(DateTime(2009, 10, 13)));

        await uc.selectDayAndCancel('22');
        expect(uc.selectedDate, equals(DateTime(2009, 10, 13))); // not changed
      });

      testWidgets('empty name is not allowed', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final repo = InMemoryVehicleRepo();
        repo.vehicles.clear();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );
        await uc.saveForm(settle: true);

        expect(repo.vehicles, isEmpty);
        expect(uc.nameError, isNotEmpty);
        expect(uc.dateError, isNotEmpty);

        await uc.enterName('  ');
        await uc.saveForm(settle: true);

        expect(repo.vehicles, isEmpty);
        expect(uc.nameError, isNotEmpty);
        expect(uc.dateError, isNotEmpty);
      });

      testWidgets('shows snackbar on error', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final repo = InMemoryVehicleRepo();
        repo.vehicles.clear();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );
        final completer = repo.lockCreate();
        await uc.enterName('   Ford T');
        await uc.selectDayAndConfirm('13');
        await uc.selectDistanceUnit('km');
        await uc.saveForm();

        expect(uc.nameError, isNull);
        expect(uc.dateError, isNull);
        expect(uc.saveButton.enabled, isFalse);

        completer.completeError(Exception('Network error'));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(uc.saveButton.enabled, isTrue);
      });
    });
    group('Editing', () {
      testWidgets(
          'shows loaded vehicle properties', (WidgetTester tester) async {
        final vehicle = Vehicle(
          'veh-id',
          name: 'Suzuki Grand Vitara',
          manufactureDate: DateTime(2005, 02, 03),
          distanceUnit: .km,
        );
        final uc = VehicleFormUC(tester);
        final repo = InMemoryVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo, vehicle: vehicle),
          ),
        );
        expect(uc.selectedDate, equals(vehicle.manufactureDate));
        expect(uc.selectedDistanceUnit, equals(vehicle.distanceUnit));
        expect(uc.nameField.value, equals(vehicle.name));
      });
    });
  });
}

class ClockMock extends Mock implements Clock ;
