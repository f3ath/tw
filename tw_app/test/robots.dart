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
import 'package:tw_app/ui/services/service_screen.dart';
import 'package:tw_app/ui/services/service_form_screen.dart';
import 'package:tw_app/ui/services/service_card.dart';
import 'package:tw_app/ui/services/service_delete_dialog.dart';
import 'package:tw_app/ui/operations/operation_screen.dart';

final findWelcomeScreen = find.byType(WelcomeScreen);
final findGarageScreen = find.byType(GarageScreen);
final findVehicleFormScreen = find.byType(VehicleFormScreen);
final findScheduleScreen = find.byType(ScheduleScreen);
final findScheduleFormScreen = find.byType(ScheduleFormScreen);
final findServiceScreen = find.byType(ServiceScreen);
final findServiceFormScreen = find.byType(ServiceFormScreen);
final findOperationScreen = find.byType(OperationScreen);

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

  Finder findVehicleNewServiceButton(String id) => find.byKey(VehicleCard.newServiceButtonKey(id));

  Future<void> tapVehicleNewService(String id, {PumpMode pump = .settle}) async {
    final button = findVehicleNewServiceButton(id);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpAfterAction(pump);
  }

  Future<void> tapVehicleMenu(String id) async {
    await tester.tap(findVehicleMenu(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapVehicleMenuEdit(String id) => _tapVehicleMenuAction(id, .edit);

  Future<void> tapVehicleMenuSchedules(String id) => _tapVehicleMenuAction(id, .schedules);

  Future<void> tapVehicleMenuServices(String id) => _tapVehicleMenuAction(id, .services);

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

class ServiceRobot(super.tester) extends TestRobot {
  final findNewServiceButton = find.byKey(ServiceScreen.addButtonKey);
  final findDeleteConfirmation = find.byKey(ServiceDeleteDialog.confirmationKey);
  final findDeleteError = find.byKey(ServiceScreen.deleteErrorSnackBarKey);

  ServiceDeleteDialog get deleteDialog =>
      tester.widget<ServiceDeleteDialog>(findDeleteConfirmation);

  Future<void> tapNewService({PumpMode pump = .settle}) async {
    await tester.tap(findNewServiceButton);
    await pumpAfterAction(pump);
  }

  Finder findServiceCard(String id) => find.byKey(ServiceScreen.serviceKey(id));

  Finder findServiceMenu(String id) => find.byKey(ServiceCard.menuKey(id));

  Future<void> tapServiceMenu(String id) async {
    await tester.tap(findServiceMenu(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapServiceMenuEdit(String id) => _tapServiceMenuAction(id, .edit);

  Future<void> tapServiceMenuDelete(String id) => _tapServiceMenuAction(id, .delete);

  Future<void> confirmServiceDeletion({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(ServiceDeleteDialog.deleteButtonKey));
    await pumpAfterAction(pump);
  }

  Future<void> cancelServiceDeletion() async {
    await tester.tap(find.byKey(ServiceDeleteDialog.cancelButtonKey));
    await tester.pumpAndSettle();
  }

  Future<void> dismissServiceDeletion() async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> _tapServiceMenuAction(String id, ServiceAction action) async {
    await tapServiceMenu(id);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is PopupMenuItem<ServiceAction> && widget.value == action,
            description: 'service menu item for ${action.name}',
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(ServiceScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }
}

class OperationRobot(super.tester) extends TestRobot {
  Finder findOperationCard(String id) => find.byKey(OperationScreen.operationKey(id));

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(OperationScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }
}

class ServiceFormRobot(super.tester) extends TestRobot {
  final findDateField = find.byKey(ServiceFormScreen.dateFieldKey);
  final findOdometerField = find.byKey(ServiceFormScreen.odometerFieldKey);
  final findDetailsField = find.byKey(ServiceFormScreen.detailsFieldKey);
  final findSaveButton = find.byKey(ServiceFormScreen.saveButtonKey);
  final findDatePickerDialog = find.byType(DatePickerDialog);
  final findSaveError = find.byKey(ServiceFormScreen.errorSnackBarKey);

  FilledButton get saveButton => tester.widget<FilledButton>(findSaveButton);
  DatePickerDialog get datePicker => tester.widget<DatePickerDialog>(findDatePickerDialog);

  FormFieldState<DateTime> get dateField => tester.state<FormFieldState<DateTime>>(findDateField);
  FormFieldState<String> get odometerField =>
      tester.state<FormFieldState<String>>(findOdometerField);
  FormFieldState<String> get detailsField => tester.state<FormFieldState<String>>(findDetailsField);

  DateTime? get selectedDate => dateField.value;
  String? get odometer => odometerField.value;
  String? get details => detailsField.value;
  String? get dateError => dateField.errorText;
  String? get odometerError => odometerField.errorText;

  bool get dateEnabled => _dateInput.enabled ?? true;
  bool get odometerEnabled => tester.widget<TextFormField>(findOdometerField).enabled;
  bool get detailsEnabled => tester.widget<TextFormField>(findDetailsField).enabled;
  String? get distanceUnitLabel => _odometerInput.decoration?.suffixText;

  TextField get _dateInput => tester.widget<TextField>(
    find.descendant(of: findDateField, matching: find.byType(TextField)),
  );

  TextField get _odometerInput => tester.widget<TextField>(
    find.descendant(of: findOdometerField, matching: find.byType(TextField)),
  );

  Future<void> enterOdometer(String value) => _enter(findOdometerField, value);
  Future<void> enterDetails(String value) => _enter(findDetailsField, value);

  Future<void> setDateValue(DateTime? value) async {
    dateField.didChange(value);
    await tester.pump();
  }

  Future<void> _enter(Finder field, String value) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> saveForm({PumpMode pump = .frame}) async {
    await tester.ensureVisible(findSaveButton);
    await tester.tap(findSaveButton);
    await pumpAfterAction(pump);
  }

  Future<void> openDatePicker() async {
    await tester.ensureVisible(findDateField);
    await tester.tap(findDateField);
    await tester.pumpAndSettle();
  }

  Future<void> selectDayAndConfirm(String day) async {
    await openDatePicker();
    await tester.tap(
      find.descendant(of: findDatePickerDialog, matching: find.text(day)).hitTestable(),
    );
    await tester.pumpAndSettle();
    final labels = MaterialLocalizations.of(tester.element(findDatePickerDialog));
    await tester.tap(
      find.descendant(of: findDatePickerDialog, matching: find.text(labels.okButtonLabel)),
    );
    await tester.pumpAndSettle();
  }
}
