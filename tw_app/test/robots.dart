import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/garage/garage_screen.dart';
import 'package:tw_app/ui/garage/vehicle_card.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';
import 'package:tw_app/ui/schedules/schedule_card.dart';
import 'package:tw_app/ui/schedules/schedule_form_screen.dart';
import 'package:tw_app/ui/garage/vehicle_form_screen.dart';
import 'package:tw_app/ui/welcome/welcome_screen.dart';

final findWelcomeScreen = find.byType(WelcomeScreen);
final findGarageScreen = find.byType(GarageScreen);
final findVehicleFormScreen = find.byType(VehicleFormScreen);
final findScheduleScreen = find.byType(ScheduleScreen);
final findScheduleFormScreen = find.byType(ScheduleFormScreen);

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

  final findNewVehicleButton = find.byKey(GarageScreen.addButtonKey);

  Future<void> tapNewVehicle({PumpMode pump = .settle}) async {
    await tester.tap(findNewVehicleButton);
    await pumpAfterAction(pump);
  }

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(GarageScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }

  Finder findVehicleCard(String id) => find.byKey(GarageScreen.vehicleCardKey(id));

  Finder findVehicleMenu(String id) => find.byKey(VehicleCard.menuKey(id));

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

  String? get name => nameField.value;

  String? get nameError => nameField.errorText;

  String? get dateError => dateField.errorText;

  Future<void> saveForm({PumpMode pump = .frame}) async {
    await tester.ensureVisible(findSaveButton);
    await tester.tap(findSaveButton);
    await pumpAfterAction(pump);
  }

  Future<void> enterName(String name) async {
    await tester.ensureVisible(findNameField);
    await tester.enterText(findNameField, name);
    await tester.pump();
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

class ScheduleRobot(super.tester) extends TestRobot {
  final findNewScheduleButton = find.byKey(ScheduleScreen.addButtonKey);

  Finder findScheduleMenu(String id) => find.byKey(ScheduleCard.menuKey(id));

  Future<void> tapScheduleMenu(String id) async {
    await tester.tap(findScheduleMenu(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapScheduleMenuEdit(String id) => _tapScheduleMenuAction(id, .edit);

  Future<void> tapScheduleMenuDelete(String id) => _tapScheduleMenuAction(id, .delete);

  Future<void> _tapScheduleMenuAction(String id, ScheduleAction action) async {
    await tapScheduleMenu(id);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is PopupMenuItem<ScheduleAction> && widget.value == action,
            description: 'schedule menu item for ${action.name}',
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapNewSchedule({PumpMode pump = .settle}) async {
    await tester.tap(findNewScheduleButton);
    await pumpAfterAction(pump);
  }

  Finder findScheduleCard(String id) => find.byKey(ScheduleScreen.scheduleKey(id));

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(ScheduleScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }
}

class ScheduleFormRobot(super.tester) extends TestRobot {
  Future<void> fill({
    required String name,
    required String distance,
    required String months,
    required String details,
  }) async {
    await enterName(name);
    await enterDistance(distance);
    await enterMonths(months);
    await enterDetails(details);
  }

  FilledButton get saveButton =>
      tester.widget<FilledButton>(find.byKey(ScheduleFormScreen.saveButtonKey));

  String? get nameError => _error(ScheduleFormScreen.nameFieldKey);
  String? get distanceError => _error(ScheduleFormScreen.distanceFieldKey);
  String? get monthsError => _error(ScheduleFormScreen.monthsFieldKey);

  Future<void> enterName(String value) => _enter(ScheduleFormScreen.nameFieldKey, value);
  Future<void> enterDistance(String value) => _enter(ScheduleFormScreen.distanceFieldKey, value);
  Future<void> enterMonths(String value) => _enter(ScheduleFormScreen.monthsFieldKey, value);
  Future<void> enterDetails(String value) => _enter(ScheduleFormScreen.detailsFieldKey, value);

  Future<void> saveForm({PumpMode pump = .frame}) async {
    final button = find.byKey(ScheduleFormScreen.saveButtonKey);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpAfterAction(pump);
  }

  Future<void> _enter(Key key, String value) async {
    final field = find.byKey(key);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  String? _error(Key key) => tester.state<FormFieldState<String>>(find.byKey(key)).errorText;

  String? get name => _value(ScheduleFormScreen.nameFieldKey);
  String? get intervalDistance => _value(ScheduleFormScreen.distanceFieldKey);
  String? get intervalMonths => _value(ScheduleFormScreen.monthsFieldKey);
  String? get details => _value(ScheduleFormScreen.detailsFieldKey);

  String? _value(Key key) => tester.state<FormFieldState<String>>(find.byKey(key)).value;
}
