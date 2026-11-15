import 'package:flutter/services.dart';
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
import 'package:tw_app/ui/operations/operation_card.dart';
import 'package:tw_app/ui/operations/operation_delete_dialog.dart';
import 'package:tw_app/ui/operations/operation_form_screen.dart';
import 'package:tw_app/ui/schedules/schedule_autocomplete_item.dart';
import 'package:tw_app/ui/schedules/schedule_summary.dart';
import 'package:tw_app/ui/operations/schedule_selection_screen.dart';

final findWelcomeScreen = find.byType(WelcomeScreen);
final findGarageScreen = find.byType(GarageScreen);
final findVehicleFormScreen = find.byType(VehicleFormScreen);
final findScheduleScreen = find.byType(ScheduleScreen);
final findScheduleFormScreen = find.byType(ScheduleFormScreen);
final findServiceScreen = find.byType(ServiceScreen);
final findServiceFormScreen = find.byType(ServiceFormScreen);
final findOperationScreen = find.byType(OperationScreen);
final findOperationFormScreen = find.byType(OperationFormScreen);
final findScheduleSelectionScreen = find.byType(ScheduleSelectionScreen);

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

  Future<void> _enterText(Finder field, String value) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> _tapSave(Finder button, {PumpMode pump = .frame}) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpAfterAction(pump);
  }

  Future<void> _openDatePicker(Finder field, {bool ensureVisible = false}) async {
    if (ensureVisible) await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
  }

  Future<void> _selectDatePickerDay(
    Finder field,
    String day, {
    required bool confirm,
    bool ensureVisible = false,
  }) async {
    await _openDatePicker(field, ensureVisible: ensureVisible);
    final dialog = find.byType(DatePickerDialog);
    await tester.tap(find.descendant(of: dialog, matching: find.text(day)).hitTestable());
    await tester.pumpAndSettle();
    final labels = MaterialLocalizations.of(tester.element(dialog));
    final label = confirm ? labels.okButtonLabel : labels.cancelButtonLabel;
    await tester.tap(find.descendant(of: dialog, matching: find.text(label)));
    await tester.pumpAndSettle();
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

  Future<void> saveForm({PumpMode pump = .frame}) => _tapSave(findSaveButton, pump: pump);

  Future<void> enterName(String name) => _enterText(findNameField, name);

  Future<void> selectDayAndConfirm(String day) =>
      _selectDatePickerDay(findDateField, day, confirm: true);

  Future<void> selectDayAndCancel(String day) =>
      _selectDatePickerDay(findDateField, day, confirm: false);

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

  Future<void> enterName(String value) =>
      _enterText(find.byKey(ScheduleFormScreen.nameFieldKey), value);
  Future<void> enterDistance(String value) =>
      _enterText(find.byKey(ScheduleFormScreen.distanceFieldKey), value);
  Future<void> enterMonths(String value) =>
      _enterText(find.byKey(ScheduleFormScreen.monthsFieldKey), value);
  Future<void> enterDetails(String value) =>
      _enterText(find.byKey(ScheduleFormScreen.detailsFieldKey), value);

  Future<void> saveForm({PumpMode pump = .frame}) =>
      _tapSave(find.byKey(ScheduleFormScreen.saveButtonKey), pump: pump);

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

  Future<void> tapServiceCard(String id, {PumpMode pump = .settle}) async {
    final card = findServiceCard(id);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await pumpAfterAction(pump);
  }

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
  final findNewOperationButton = find.byKey(OperationScreen.addButtonKey);

  Future<void> tapNewOperation({PumpMode pump = .settle}) async {
    await tester.tap(findNewOperationButton);
    await pumpAfterAction(pump);
  }

  final findDeleteConfirmation = find.byKey(OperationDeleteDialog.confirmationKey);
  final findDeleteError = find.byKey(OperationScreen.deleteErrorSnackBarKey);

  Future<void> tapOperationMenuEdit(String id) => _tapOperationMenuAction(id, .edit);
  Future<void> tapOperationMenuDelete(String id) => _tapOperationMenuAction(id, .delete);

  Future<void> _tapOperationMenuAction(String id, OperationAction action) async {
    final menu = find.byKey(OperationCard.menuKey(id));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is PopupMenuItem<OperationAction> && widget.value == action,
            description: 'operation menu item for ${action.name}',
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmOperationDeletion({PumpMode pump = .settle}) async {
    await tester.tap(find.byKey(OperationDeleteDialog.deleteButtonKey));
    await pumpAfterAction(pump);
  }

  Future<void> cancelOperationDeletion() async {
    await tester.tap(find.byKey(OperationDeleteDialog.cancelButtonKey));
    await tester.pumpAndSettle();
  }

  Future<void> dismissOperationDeletion() async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Service get selectedService =>
      tester.widget<OperationScreen>(findOperationScreen).vehicleService.service;
  final findVehicleNameText = find.byKey(OperationScreen.vehicleNameTextKey);
  final findServiceDateText = find.byKey(OperationScreen.serviceDateTextKey);

  Text get vehicleNameText => tester.widget<Text>(findVehicleNameText);
  Text get serviceDateText => tester.widget<Text>(findServiceDateText);

  Finder findOperationCard(String id) => find.byKey(OperationScreen.operationKey(id));

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(OperationScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }
}

class ScheduleSelectionRobot(super.tester) extends TestRobot {
  final findSaveError = find.byKey(ScheduleSelectionScreen.errorSnackBarKey);
  final findSavingIndicator = find.byKey(ScheduleSelectionScreen.savingIndicatorKey);

  Finder findScheduleCard(String id) => find.byKey(ScheduleSelectionScreen.scheduleKey(id));

  ListTile scheduleTile(String id) => tester.widget<ListTile>(
    find.descendant(of: findScheduleCard(id), matching: find.byType(ListTile)),
  );

  Future<void> selectSchedule(String id, {PumpMode pump = .frame}) async {
    final card = findScheduleCard(id);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await pumpAfterAction(pump);
  }

  Future<void> tapRetry({PumpMode pump = .frame}) async {
    await tester.tap(find.byKey(ScheduleSelectionScreen.retryButtonKey));
    await pumpAfterAction(pump);
  }
}

class OperationFormRobot(super.tester) extends TestRobot {
  final findNameField = find.byKey(OperationFormScreen.nameFieldKey);
  final findDetailsField = find.byKey(OperationFormScreen.detailsFieldKey);
  final findSaveButton = find.byKey(OperationFormScreen.saveButtonKey);
  final findSaveError = find.byKey(OperationFormScreen.errorSnackBarKey);

  FilledButton get saveButton => tester.widget<FilledButton>(findSaveButton);
  String? get name => tester.state<FormFieldState<String>>(findNameField).value;
  String? get details => tester.state<FormFieldState<String>>(findDetailsField).value;
  String? get nameError => tester.state<FormFieldState<String>>(findNameField).errorText;
  bool get nameEnabled => tester.widget<TextFormField>(findNameField).enabled;
  bool get detailsEnabled => tester.widget<TextFormField>(findDetailsField).enabled;

  final findScheduleSummary = find.byType(ScheduleSummary);
  final findSuggestionsLoading = find.byKey(OperationFormScreen.suggestionsLoadingKey);
  final findSuggestionsError = find.byKey(OperationFormScreen.suggestionsErrorKey);

  Finder findScheduleSuggestion(String id) => find.byWidgetPredicate(
    (widget) => widget is ScheduleAutocompleteItem && widget.vehicleSchedule.schedule.id == id,
  );

  Finder findSummaryText(String text) =>
      find.descendant(of: findScheduleSummary, matching: find.text(text));

  Finder findSuggestionText(String id, String text) =>
      find.descendant(of: findScheduleSuggestion(id), matching: find.text(text));

  bool isSuggestionHighlighted(String id) =>
      tester.widget<ScheduleAutocompleteItem>(findScheduleSuggestion(id)).highlighted;

  Future<void> focusName() async {
    await tester.ensureVisible(findNameField);
    await tester.tap(findNameField);
    await tester.pumpAndSettle();
  }

  Future<void> selectSchedule(String id) async {
    final suggestion = findScheduleSuggestion(id);
    await tester.ensureVisible(suggestion);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();
  }

  Future<void> selectNextSuggestionWithKeyboard() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }

  Future<void> confirmSuggestionWithKeyboard() async {
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
  }

  Future<void> retrySuggestions({PumpMode pump = .settle}) async {
    await tester.tap(find.byKey(OperationFormScreen.suggestionsRetryKey));
    await pumpAfterAction(pump);
  }

  Future<void> enterName(String value) => _enterText(findNameField, value);
  Future<void> enterDetails(String value) => _enterText(findDetailsField, value);
  Future<void> saveForm({PumpMode pump = .frame}) => _tapSave(findSaveButton, pump: pump);
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

  Future<void> enterOdometer(String value) => _enterText(findOdometerField, value);
  Future<void> enterDetails(String value) => _enterText(findDetailsField, value);

  Future<void> setDateValue(DateTime? value) async {
    dateField.didChange(value);
    await tester.pump();
  }

  Future<void> saveForm({PumpMode pump = .frame}) => _tapSave(findSaveButton, pump: pump);

  Future<void> openDatePicker() => _openDatePicker(findDateField, ensureVisible: true);

  Future<void> selectDayAndConfirm(String day) =>
      _selectDatePickerDay(findDateField, day, confirm: true, ensureVisible: true);
}
