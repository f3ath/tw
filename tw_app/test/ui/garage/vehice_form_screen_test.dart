import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tw_app/domain/vehicle.dart';
import 'package:tw_app/testing/fake.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

void main() {
  group('VehicleFormScreen', () {
    testWidgets('distance units are selectable', (WidgetTester tester) async {
      final repo = FakeVehicleRepo();
      await tester.pumpWidget(MaterialApp(home: VehicleFormScreen(repo: repo)));

      expect(selectedDistanceUnit(tester), equals(DistanceUnit.mi));

      await tester.tap(findDistanceUnit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('km').hitTestable());
      await tester.pumpAndSettle();

      expect(selectedDistanceUnit(tester), equals(DistanceUnit.km));
    });

    testWidgets('manufacture date is selectable', (WidgetTester tester) async {
      final repo = FakeVehicleRepo();
      final clock = ClockMock();
      when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
      final dialog = find.byType(DatePickerDialog);
      await tester.pumpWidget(
        MaterialApp(
          home: VehicleFormScreen(clock: clock, repo: repo),
        ),
      );

      expect(selectedDate(tester), equals(''));

      await tester.tap(findDate);
      await tester.pumpAndSettle();
      await selectDayAndConfirm(tester, dialog, '13');

      expect(selectedDate(tester), equals('2009-10-13'));

      await tester.tap(findDate);
      await tester.pumpAndSettle();
      await selectDayAndCancel(tester, dialog, '22');

      expect(selectedDate(tester), equals('2009-10-13')); // not changed
    });

    testWidgets('form validation and save', (WidgetTester tester) async {
      final repo = FakeVehicleRepo();
      final clock = ClockMock();
      when(() => clock.now()).thenReturn(DateTime(2009, 10, 15));
      await tester.pumpWidget(
        MaterialApp(
          home: VehicleFormScreen(clock: clock, repo: repo),
        ),
      );
      await tester.tap(findSaveButton);
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(tester.state<FormFieldState<String>>(findName).errorText, isNotEmpty);
      expect(tester.state<FormFieldState<String>>(findDate).errorText, isNotEmpty);

      await tester.enterText(findName, '  ');
      await tester.pumpAndSettle();
      await tester.tap(findSaveButton);
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(tester.state<FormFieldState<String>>(findName).errorText, isNotEmpty);
      expect(tester.state<FormFieldState<String>>(findDate).errorText, isNotEmpty);

      await tester.enterText(findName, '   Ford T');
      await tester.tap(findDate);
      await tester.pumpAndSettle();
      await selectDayAndConfirm(tester, find.byType(DatePickerDialog), '13');
      await tester.pumpAndSettle();
      await tester.tap(findDistanceUnit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('km').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(findSaveButton);
      await tester.pump();

      expect(tester.state<FormFieldState<String>>(findName).errorText, isNull);
      expect(tester.state<FormFieldState<String>>(findDate).errorText, isNull);

      expect(repo.created.last.name, equals('Ford T'));
      expect(repo.created.last.distanceUnit, equals(DistanceUnit.km));
      expect(repo.created.last.manufactureDate, equals(DateTime(2009, 10, 13)));

      expect(tester.widget<FilledButton>(findSaveButton).enabled, isFalse);

      repo.createCompleter.complete();
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(findSaveButton).enabled, isTrue);
    });
  });
}

final findDistanceUnit = find.byKey(VehicleFormScreen.distanceUnitFieldKey);
final findDate = find.byKey(VehicleFormScreen.dateFieldKey);
final findName = find.byKey(VehicleFormScreen.nameFieldKey);
final findSaveButton = find.byKey(VehicleFormScreen.saveButtonKey);

Future<void> selectDayAndConfirm(WidgetTester tester, Finder dialog, String day) async {
  await selectDay(tester, dialog, day);
  final context = tester.element(dialog);
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.text(MaterialLocalizations.of(context).okButtonLabel),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectDayAndCancel(WidgetTester tester, Finder dialog, String day) async {
  await selectDay(tester, dialog, day);
  final context = tester.element(dialog);
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.text(MaterialLocalizations.of(context).cancelButtonLabel),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectDay(WidgetTester tester, Finder dialog, String day) async {
  await tester.tap(find.descendant(of: dialog, matching: find.text(day)).hitTestable());
  await tester.pumpAndSettle();
}

DistanceUnit? selectedDistanceUnit(WidgetTester tester) =>
    tester.state<FormFieldState<DistanceUnit>>(findDistanceUnit).value;

String selectedDate(WidgetTester tester) =>
    tester.widget<TextFormField>(find.byKey(VehicleFormScreen.dateFieldKey)).controller!.text;

class ClockMock extends Mock implements Clock;
