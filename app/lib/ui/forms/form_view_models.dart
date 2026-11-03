import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../../domain/repositories.dart';
import '../core/command_view_model.dart';

abstract class DraftViewModel() extends CommandViewModel {
  bool dirty = false;
  void changed() {
    dirty = true;
    notifyListeners();
  }

  String? error(String field) => failure?.field == field ? failure?.message : null;
}

class VehicleFormViewModel(
  final VehicleMaintenanceRepository repository,
  final DateTime today, {
  final Vehicle? original,
}) extends DraftViewModel {
  this
    : id = original?.id ?? repository.newId(),
      name = original?.name ?? '',
      date = dateText(original?.manufactureDate ?? today),
      distanceUnit = original?.distanceUnit ?? DistanceUnit.mi;
  String id;
  String name, date, odometer = '';
  DistanceUnit distanceUnit;
  Future<bool> save() => run(() async {
    final manufactured = parseDate(date);
    final initial = original == null ? whole(odometer, 'mileage') : null;
    id = await repository.saveVehicle(
      Vehicle(id, name: name.trim(), manufactureDate: manufactured, distanceUnit: distanceUnit),
      initialMileage: initial,
      expected: original,
    );
    dirty = false;
  });
}

class ItemFormViewModel(
  final VehicleMaintenanceRepository repository,
  final Vehicle vehicle, {
  final Schedule? original,
}) extends DraftViewModel {
  this
    : id = original?.id ?? repository.newId(),
      name = original?.name ?? '',
      details = original?.details ?? '',
      intervalDistance = original?.intervalDistance?.toString() ?? '',
      intervalMonths = original?.intervalMonths?.toString() ?? '';
  String id;
  String name, details, intervalDistance, intervalMonths;
  Future<bool> save() => run(() async {
    id = await repository.saveItem(
      Schedule(
        id: id,
        vehicleId: vehicle.id,
        name: name.trim(),
        intervalDistance: intervalDistance.isEmpty ? null : whole(intervalDistance, 'interval'),
        intervalMonths: intervalMonths.isEmpty ? null : whole(intervalMonths, 'interval'),
        isArchived: original?.isArchived ?? false,
        details: details,
      ),
      expected: original,
    );
    dirty = false;
  });
}

class OperationDraft(final String id, {var String name = '', var String details = ''});

class ServiceFormViewModel(
  final VehicleMaintenanceRepository repository,
  final Vehicle vehicle,
  final DateTime today, {
  final Service? original,
}) extends DraftViewModel {
  this
    : id = original?.id ?? repository.newId(),
      date = dateText(original?.date ?? today),
      odometer = original?.odometer.toString() ?? '' {
    _originalOperations = original == null
        ? const []
        : repository.snapshot.operationsFor(original!.id);
    selected = {
      for (final operation in _originalOperations)
        if (operation.scheduleId != null) operation.scheduleId!,
    };
    custom = [
      for (final operation in _originalOperations)
        if (operation.scheduleId == null)
          OperationDraft(operation.id, name: operation.name, details: operation.details),
    ];
  }
  String id;
  String date, odometer;
  late final List<Operation> _originalOperations;
  late final Set<String> selected;
  late final List<OperationDraft> custom;
  bool get isToday => date == dateText(today);
  List<Schedule> get suggestions => isToday
      ? const SchedulingPolicy()
            .due(repository.snapshot, vehicle.id)
            .where((due) => due.status == DueStatus.overdue)
            .map((due) => due.item)
            .toList()
      : [];
  List<Schedule> get others {
    final suggested = suggestions.map((item) => item.id).toSet();
    return repository.snapshot.items
        .where(
          (item) =>
              item.vehicleId == vehicle.id &&
              !suggested.contains(item.id) &&
              (!item.isArchived ||
                  _originalOperations.any((operation) => operation.scheduleId == item.id)),
        )
        .toList();
  }

  int get count => selected.length + custom.where((draft) => draft.name.trim().isNotEmpty).length;
  int? get estimate => repository.snapshot.estimate(vehicle.id);
  void toggle(String id, bool value) {
    value ? selected.add(id) : selected.remove(id);
    changed();
  }

  void addCustom() {
    custom.add(OperationDraft(repository.newId()));
    changed();
  }

  Future<bool> save() => run(() async {
    final operations = <Operation>[
      for (final scheduleId in selected)
        Operation(
          _originalOperations
                  .where((operation) => operation.scheduleId == scheduleId)
                  .firstOrNull
                  ?.id ??
              repository.newId(),
          serviceId: id,
          scheduleId: scheduleId,
          name: repository.snapshot.item(scheduleId).name,
          details: repository.snapshot.item(scheduleId).details,
        ),
      for (final draft in custom)
        if (draft.name.trim().isNotEmpty)
          Operation(
            draft.id,
            serviceId: id,
            name: draft.name.trim(),
            details: draft.details.trim(),
          ),
    ];
    id = await repository.saveService(
      Service(
        id,
        vehicleId: vehicle.id,
        date: parseDate(date),
        odometer: whole(odometer, 'mileage'),
        details: original?.details ?? '',
      ),
      operations: operations,
      expected: original,
      expectedOperations: original == null ? null : _originalOperations,
    );
    dirty = false;
  });
}

class SettingsViewModel(final SettingsRepository repository) extends DraftViewModel {
  String address = '';
  Future<bool> load() => run(() async {
    address = await repository.load();
  });
  Future<bool> save() => run(() async {
    await repository.save(address.trim());
    dirty = false;
  });
}

DateTime parseDate(String text) {
  final value = DateTime.tryParse(text);
  if (value == null || dateText(value) != text) invalid('Enter a valid date: YYYY-MM-DD.', 'date');
  return day(value);
}

int whole(String text, String field) {
  if (!RegExp(r'^\d+$').hasMatch(text)) invalid('Enter a nonnegative whole number.', field);
  final value = int.tryParse(text);
  if (value == null) invalid('Enter a whole number within the supported range.', field);
  return value;
}
