import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/garage/vehicle_card.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

final findWelcomeScreen = find.byType(WelcomeScreen);
final findGarageScreen = find.byType(GarageScreen);
final findVehicleFormScreen = find.byType(VehicleFormScreen);
final findScheduleScreen = find.byType(ScheduleScreen);

enum PumpMode { none, frame, settle }

class TestRobot(final WidgetTester tester) {
  Future<void> pumpAfterAction(PumpMode mode) async {
    switch (mode) {
      case .none:
        return;
      case .frame:
        await tester.pump();
        return;
      case .settle:
        await tester.pumpAndSettle();
        return;
    }
  }

  Future<void> tapAlertDialogButton(String text) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(text)));
  }
}

class WelcomeRobot(super.tester) extends TestRobot {
  final findLoginButton = find.byKey(WelcomeScreen.loginButtonKey);

  FilledButton get loginButton => tester.widget<FilledButton>(findLoginButton);

  Future<void> tapLoginButton({PumpMode pump = .frame}) async {
    await tester.tap(findLoginButton);
    await pumpAfterAction(pump);
  }
}

class GarageRobot(super.tester) extends TestRobot {
  final findUserNameText = find.byKey(GarageScreen.userNameTextKey);
  final findLogoutButton = find.byKey(GarageScreen.logoutButtonKey);

  Text get userNameText => tester.widget<Text>(findUserNameText);

  Future<void> tapLogoutButton({PumpMode pump = .frame}) async {
    await tester.tap(findLogoutButton);
    await pumpAfterAction(pump);
  }

  final findAddNewVehicleButton = find.byKey(GarageScreen.addButtonKey);

  Future<void> tapAddNewVehicleButton({PumpMode pump = .frame}) async {
    await tester.tap(findAddNewVehicleButton);
    await pumpAfterAction(pump);
  }

  Finder findVehicleCard(String id) => find.byKey(GarageScreen.vehicleCardKey(id));

  Finder findVehicleMenu(String id) => find.byKey(ValueKey('menu-$id'));

  Future<void> tapVehicleMenu(String id) async {
    await tester.tap(findVehicleMenu(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapVehicleMenuEdit(String id) => _tapVehicleMenuAction(id, .edit);

  Future<void> tapVehicleMenuSchedules(String id) => _tapVehicleMenuAction(id, .schedules);

  Future<void> tapVehicleMenuDelete(String id) => _tapVehicleMenuAction(id, .delete);

  Future<void> _tapVehicleMenuAction(String id, VehicleAction action) async {
    await tapVehicleMenu(id);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is PopupMenuItem<VehicleAction> && widget.value == action,
            description: 'vehicle menu item for ${action.name}',
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }
}

class VehicleFormRobot(super.tester) extends TestRobot {
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

  Future<void> saveForm({PumpMode pump = .frame}) async {
    await tester.tap(findSaveButton);
    await pumpAfterAction(pump);
  }

  Future<void> enterName(String name) async {
    await tester.enterText(findNameField, name);
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAndConfirm(String day) async {
    await _openDatePickerAndSelectDay(day);
    final labels = MaterialLocalizations.of(tester.element(findDatePickerDialog));
    await _tapDatePickerButton(labels.okButtonLabel);
  }

  Future<void> selectDayAndCancel(String day) async {
    await _openDatePickerAndSelectDay(day);
    final labels = MaterialLocalizations.of(tester.element(findDatePickerDialog));
    await _tapDatePickerButton(labels.cancelButtonLabel);
  }

  Future<void> _openDatePickerAndSelectDay(String day) async {
    await tester.tap(findDateField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: findDatePickerDialog, matching: find.text(day)).hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> _tapDatePickerButton(String label) async {
    await tester.tap(find.descendant(of: findDatePickerDialog, matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> selectDistanceUnit(String name) async {
    await tester.tap(findDistanceUnitField);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(DropdownMenuItem<DistanceUnit>), matching: find.text(name))
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }
}
