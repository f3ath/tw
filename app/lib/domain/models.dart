DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
String dateText(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

enum FailureKind() {
  validation,
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

class const Vehicle({
  required final String id,
  required final String name,
  required final DateTime manufactured,
  required final String unit,
}) {}

class const MaintenanceItem({
  required final String id,
  required final String vehicleId,
  required final String description,
  final int? distance,
  final int? months,
  final bool archived = false,
}) {
  MaintenanceItem withArchive(bool value) => MaintenanceItem(
    id: id,
    vehicleId: vehicleId,
    description: description,
    distance: distance,
    months: months,
    archived: value,
  );
}

class ServiceRecord({
  required final String id,
  required final String vehicleId,
  required final DateTime date,
  required final int mileage,
  Iterable<String> links = const [],
  Iterable<String> custom = const [],
}) {
  this : links = List.unmodifiable(links), custom = List.unmodifiable(custom);
  final List<String> links, custom;
}

class Garage({
  Iterable<Vehicle> vehicles = const [],
  Iterable<MaintenanceItem> items = const [],
  Iterable<ServiceRecord> services = const [],
  required final DateTime asOf,
}) {
  this
    : vehicles = List.unmodifiable(vehicles),
      items = List.unmodifiable(items),
      services = List.unmodifiable(services);
  final List<Vehicle> vehicles;
  final List<MaintenanceItem> items;
  final List<ServiceRecord> services;
  Garage copy({
    Iterable<Vehicle>? vehicles,
    Iterable<MaintenanceItem>? items,
    Iterable<ServiceRecord>? services,
    DateTime? asOf,
  }) => Garage(
    vehicles: vehicles ?? this.vehicles,
    items: items ?? this.items,
    services: services ?? this.services,
    asOf: asOf ?? this.asOf,
  );
  Vehicle vehicle(String id) => vehicles.firstWhere(
    (v) => v.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Vehicle unavailable.'),
  );
  MaintenanceItem item(String id) => items.firstWhere(
    (v) => v.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Item unavailable.'),
  );
  ServiceRecord service(String id) => services.firstWhere(
    (v) => v.id == id,
    orElse: () => throw const AppFailure(FailureKind.missing, 'Service unavailable.'),
  );
  List<ServiceRecord> history(String vehicleId) =>
      services.where((s) => s.vehicleId == vehicleId).toList()
        ..sort((a, b) => compareServices(b, a));
  int? estimate(String id) => history(id)
      .firstOrNull
      ?.mileage; // Deterministic mock: latest accepted actual, no extrapolation.
}

int compareServices(ServiceRecord a, ServiceRecord b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byMileage = a.mileage.compareTo(b.mileage);
  return byMileage != 0 ? byMileage : a.id.compareTo(b.id);
}

DateTime calendarAdd(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);
int calendarDifference(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

bool sameVehicle(Vehicle a, Vehicle b) =>
    a.id == b.id && a.name == b.name && a.manufactured == b.manufactured && a.unit == b.unit;
bool sameItem(MaintenanceItem a, MaintenanceItem b) =>
    a.id == b.id &&
    a.vehicleId == b.vehicleId &&
    a.description == b.description &&
    a.distance == b.distance &&
    a.months == b.months &&
    a.archived == b.archived;
bool sameStrings(List<String> a, List<String> b) =>
    a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
bool sameService(ServiceRecord a, ServiceRecord b) =>
    a.id == b.id &&
    a.vehicleId == b.vehicleId &&
    a.date == b.date &&
    a.mileage == b.mileage &&
    sameStrings(a.links, b.links) &&
    sameStrings(a.custom, b.custom);
