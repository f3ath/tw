import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

final findWelcomeScreen = find.byType(WelcomeScreen);
final findGarageScreen = find.byType(GarageScreen);
final findVehicleFormScreen = find.byType(VehicleFormScreen);

class UseCase(final WidgetTester tester) {
  final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);
  final findUserNameText = find.byKey(GarageScreen.userNameTextKey);
  final findLogoutButton = find.byKey(GarageScreen.logoutButtonKey);

  FilledButton get loginButton => tester.widget<FilledButton>(findLoginButton);

  Text get userNameText => tester.widget<Text>(findUserNameText);

  Future<void> tapLoginButton({bool pump = true, bool settle = false}) async {
    await tester.tap(findLoginButton);
    await pumpAndSettle(pump: pump, settle: settle);
  }

  Future<void> tapLogoutButton({bool pump = true, bool settle = false}) async {
    await tester.tap(findLogoutButton);
    await pumpAndSettle(pump: pump, settle: settle);
  }

  Future<void> pumpAndSettle({bool pump = true, bool settle = false}) async {
    if (!pump) return;
    if (settle) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump();
  }
}

class GarageUC(super.tester) extends UseCase {
  final findAddNewVehicleButton = find.byKey(GarageScreen.addButtonKey);

  Future<void> tapAddNewVehicleButton({bool pump = true, bool settle = false}) async {
    await tester.tap(findAddNewVehicleButton);
    await pumpAndSettle(pump: pump, settle: settle);
  }
}

class VehicleFormUC(super.tester) extends GarageUC {
  final findNameField = find.byKey(VehicleFormScreen.nameFieldKey);
  final findDistanceUnitField = find.byKey(VehicleFormScreen.distanceUnitFieldKey);
  final findDateField = find.byKey(VehicleFormScreen.dateFieldKey);
  final findDatePickerDialog = find.byType(DatePickerDialog);
  final findSaveButton = find.byKey(VehicleFormScreen.saveButtonKey);

  DistanceUnit? get selectedDistanceUnit =>
      tester.state<FormFieldState<DistanceUnit>>(findDistanceUnitField).value;

  FilledButton get saveButton => tester.widget<FilledButton>(findSaveButton);

  DateTime? get selectedDate => dateField.value;

  FormFieldState<String> get nameField => tester.state<FormFieldState<String>>(findNameField);

  FormFieldState<DateTime> get dateField => tester.state<FormFieldState<DateTime>>(findDateField);

  String? get nameError => nameField.errorText;

  String? get dateError => dateField.errorText;

  Future<void> saveForm({bool pump = true, bool settle = false}) async {
    await tester.tap(findSaveButton);
    await pumpAndSettle(pump: pump, settle: settle);
  }

  Future<void> enterName(String name) async {
    await tester.enterText(findNameField, name);
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAndConfirm(String day) async {
    await tester.tap(findDateField);
    await tester.pumpAndSettle();
    await _selectDay(day);
    final context = tester.element(findDatePickerDialog);
    await tester.tap(
      find.descendant(
        of: findDatePickerDialog,
        matching: find.text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAndCancel(String day) async {
    await tester.tap(findDateField);
    await tester.pumpAndSettle();
    await _selectDay(day);
    final context = tester.element(findDatePickerDialog);
    await tester.tap(
      find.descendant(
        of: findDatePickerDialog,
        matching: find.text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> _selectDay(String day) async {
    await tester.tap(
      find.descendant(of: findDatePickerDialog, matching: find.text(day)).hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectDistanceUnit(String name) async {
    await tester.tap(findDistanceUnitField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).hitTestable());
    await tester.pumpAndSettle();
  }
}
