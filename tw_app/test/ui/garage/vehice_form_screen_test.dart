import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/fake.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

import '../../use_case.dart';

void main() {
  group('VehicleFormScreen', () {
    group('New Vehicle', () {
      testWidgets('distance units are selectable', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final repo = FakeVehicleRepo();
        await tester.pumpWidget(
            MaterialApp(home: VehicleFormScreen(repo: repo)));

        expect(uc.selectedDistanceUnit, equals(DistanceUnit.mi));

        await uc.selectDistanceUnit('km');

        expect(uc.selectedDistanceUnit, equals(DistanceUnit.km));
      });

      testWidgets(
          'manufacture date is selectable', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final repo = FakeVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );

        expect(uc.selectedDate, isNull);

        await uc.selectDayAndConfirm('13');
        expect(uc.selectedDate, equals(DateTime(2009, 10, 13)));

        await uc.selectDayAndCancel('22');
        expect(uc.selectedDate, equals(DateTime(2009, 10, 13))); // not changed
      });

      testWidgets('form validation and save', (WidgetTester tester) async {
        final uc = VehicleFormUC(tester);
        final repo = FakeVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo),
          ),
        );
        await uc.saveForm(settle: true);

        expect(repo.created, isEmpty);
        expect(uc.nameError, isNotEmpty);
        expect(uc.dateError, isNotEmpty);

        await uc.enterName('  ');
        await uc.saveForm(settle: true);

        expect(repo.created, isEmpty);
        expect(uc.nameError, isNotEmpty);
        expect(uc.dateError, isNotEmpty);

        await uc.enterName('   Ford T');
        await uc.selectDayAndConfirm('13');
        await uc.selectDistanceUnit('km');
        await uc.saveForm();

        expect(uc.nameError, isNull);
        expect(uc.dateError, isNull);

        expect(repo.created.last.name, equals('Ford T'));
        expect(repo.created.last.distanceUnit, equals(DistanceUnit.km));
        expect(
            repo.created.last.manufactureDate, equals(DateTime(2009, 10, 13)));

        expect(uc.saveButton.enabled, isFalse);

        repo.createCompleter.completeError(Exception('Network error'));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(uc.saveButton.enabled, isTrue);
      });
    });
    group('Editing', () {
      testWidgets(
          'shows loaded vehicle properties', (WidgetTester tester) async {
        final veh = Vehicle('veh-id', name: 'Suzuki Grand Vitara',
            manufactureDate: DateTime(2005, 02, 03),
            distanceUnit: .mi);
        final uc = VehicleFormUC(tester);
        final repo = FakeVehicleRepo();
        final clock = ClockMock();
        when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
        await tester.pumpWidget(
          MaterialApp(
            home: VehicleFormScreen(clock: clock, repo: repo, vehicle: veh,),
          ),
        );
        expect(uc.selectedDate, equals(DateTime(2005, 02, 03)));
      });
    });
  });
}

class ClockMock extends Mock implements Clock ;
