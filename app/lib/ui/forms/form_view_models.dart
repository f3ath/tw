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
      date = dateText(original?.manufactured ?? today),
      unit = original?.unit ?? 'mi';
  final String id;
  String name, date, unit, mileage = '';
  Future<bool> save() => run(() async {
    final manufactured = parseDate(date);
    final initial = original == null ? whole(mileage, 'mileage') : null;
    await repository.saveVehicle(
      Vehicle(id: id, name: name.trim(), manufactured: manufactured, unit: unit),
      initialMileage: initial,
      expected: original,
    );
    dirty = false;
  });
}

class ItemFormViewModel(
  final VehicleMaintenanceRepository repository,
  final Vehicle vehicle, {
  final MaintenanceItem? original,
}) extends DraftViewModel {
  this
    : id = original?.id ?? repository.newId(),
      description = original?.description ?? '',
      distance = original?.distance?.toString() ?? '',
      months = original?.months?.toString() ?? '';
  final String id;
  String description, distance, months;
  Future<bool> save() => run(() async {
    await repository.saveItem(
      MaintenanceItem(
        id: id,
        vehicleId: vehicle.id,
        description: description.trim(),
        distance: distance.isEmpty ? null : whole(distance, 'interval'),
        months: months.isEmpty ? null : whole(months, 'interval'),
        archived: original?.archived ?? false,
      ),
      expected: original,
    );
    dirty = false;
  });
}

class ServiceFormViewModel(
  final VehicleMaintenanceRepository repository,
  final Vehicle vehicle,
  final DateTime today, {
  final ServiceRecord? original,
}) extends DraftViewModel {
  this
    : id = original?.id ?? repository.newId(),
      date = dateText(original?.date ?? today),
      mileage = original?.mileage.toString() ?? '',
      selected = {...?original?.links},
      custom = [...?original?.custom];
  final String id;
  String date, mileage;
  final Set<String> selected;
  final List<String> custom;
  bool get isToday => date == dateText(today);
  List<MaintenanceItem> get suggestions => isToday
      ? const SchedulingPolicy()
            .due(repository.snapshot, vehicle.id)
            .where((d) => d.status == DueStatus.overdue)
            .map((d) => d.item)
            .toList()
      : [];
  List<MaintenanceItem> get others {
    final suggested = suggestions.map((i) => i.id).toSet();
    return repository.snapshot.items
        .where(
          (i) =>
              i.vehicleId == vehicle.id &&
              !suggested.contains(i.id) &&
              (!i.archived || (original?.links.contains(i.id) ?? false)),
        )
        .toList();
  }

  int get count => selected.length + custom.where((s) => s.trim().isNotEmpty).length;
  int? get estimate => repository.snapshot.estimate(vehicle.id);
  void toggle(String id, bool value) {
    value ? selected.add(id) : selected.remove(id);
    changed();
  }

  Future<bool> save() => run(() async {
    await repository.saveService(
      ServiceRecord(
        id: id,
        vehicleId: vehicle.id,
        date: parseDate(date),
        mileage: whole(mileage, 'mileage'),
        links: selected,
        custom: custom.map((s) => s.trim()).where((s) => s.isNotEmpty),
      ),
      expected: original,
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
