import 'package:shared/model.dart';

export 'package:shared/model.dart' show Vehicle, DistanceUnit, Schedule, Service, Operation;

DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

String dateText(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

enum FailureKind() {
  validation,
  authentication,
  connectivity,
  missing,
  persistence,
  conflict,
}

class const AppFailure(final FailureKind kind, final String message, {final String? field})
    implements Exception {
  @override
  String toString() => message;
}

class Garage({
  Iterable<Vehicle> vehicles = const [],
  Iterable<Schedule> items = const [],
  Iterable<Service> services = const [],
  Iterable<Operation> operations = const [],
  required final DateTime asOf,
}) {
  this
    : vehicles = List.unmodifiable(vehicles),
      items = List.unmodifiable(items),
      services = List.unmodifiable(services),
      operations = List.unmodifiable(_resolveOperations(operations, items));

  final List<Vehicle> vehicles;
  final List<Schedule> items;
  final List<Service> services;
  final List<Operation> operations;

  Garage copy({
    Iterable<Vehicle>? vehicles,
    Iterable<Schedule>? items,
    Iterable<Service>? services,
    Iterable<Operation>? operations,
    DateTime? asOf,
  }) => Garage(
    vehicles: vehicles ?? this.vehicles,
    items: items ?? this.items,
    services: services ?? this.services,
    operations: operations ?? this.operations,
    asOf: asOf ?? this.asOf,
  );

  Vehicle vehicle(String id) => vehicles.firstWhere(
    (vehicle) => vehicle.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Vehicle unavailable.'),
  );

  Schedule item(String id) => items.firstWhere(
    (item) => item.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Item unavailable.'),
  );

  Service service(String id) => services.firstWhere(
    (service) => service.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Service unavailable.'),
  );

  List<Operation> operationsFor(String serviceId) =>
      List.unmodifiable(operations.where((operation) => operation.serviceId == serviceId));

  bool completes(String serviceId, String scheduleId) => operations.any(
    (operation) => operation.serviceId == serviceId && operation.scheduleId == scheduleId,
  );

  List<Service> history(String vehicleId) =>
      services.where((s) => s.vehicleId == vehicleId).toList()
        ..sort((a, b) => compareServices(b, a));

  int? estimate(String id) => history(id).firstOrNull?.odometer;
}

Iterable<Operation> _resolveOperations(
  Iterable<Operation> operations,
  Iterable<Schedule> items,
) sync* {
  final schedules = {for (final item in items) item.id: item};
  for (final operation in operations) {
    final schedule = schedules[operation.scheduleId];
    yield schedule == null
        ? operation
        : Operation(
            operation.id,
            serviceId: operation.serviceId,
            scheduleId: schedule.id,
            name: schedule.name,
            details: schedule.details,
          );
  }
}

extension ScheduleEdits on Schedule {
  Schedule withArchive(bool isArchived) => Schedule(
    id: id,
    vehicleId: vehicleId,
    name: name,
    intervalDistance: intervalDistance,
    intervalMonths: intervalMonths,
    details: details,
    isArchived: isArchived,
  );
}

int compareServices(Service a, Service b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byOdometer = a.odometer.compareTo(b.odometer);
  return byOdometer != 0 ? byOdometer : a.id.compareTo(b.id);
}

DateTime calendarAdd(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

int calendarDifference(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

bool sameVehicle(Vehicle a, Vehicle b) =>
    a.id == b.id &&
    a.name == b.name &&
    a.manufactureDate == b.manufactureDate &&
    a.distanceUnit == b.distanceUnit;

bool sameItem(Schedule a, Schedule b) =>
    a.id == b.id &&
    a.vehicleId == b.vehicleId &&
    a.name == b.name &&
    a.intervalDistance == b.intervalDistance &&
    a.intervalMonths == b.intervalMonths &&
    a.details == b.details &&
    a.isArchived == b.isArchived;

bool sameService(Service a, Service b) =>
    a.id == b.id &&
    a.vehicleId == b.vehicleId &&
    a.date == b.date &&
    a.odometer == b.odometer &&
    a.details == b.details;

bool sameOperation(Operation a, Operation b) =>
    a.id == b.id &&
    a.serviceId == b.serviceId &&
    a.scheduleId == b.scheduleId &&
    (a.scheduleId != null || a.name == b.name && a.details == b.details);

bool sameOperations(Iterable<Operation> a, Iterable<Operation> b) {
  final left = {for (final operation in a) operation.id: operation};
  final right = {for (final operation in b) operation.id: operation};
  return left.length == right.length &&
      left.entries.every(
        (entry) => right[entry.key] != null && sameOperation(entry.value, right[entry.key]!),
      );
}
