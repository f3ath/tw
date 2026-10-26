import 'package:app/data/services/services.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/repositories.dart';

class MemoryStorage() implements LocalPersistenceService {
  final values = <String, Map<String, Object?>>{};
  bool fail = false;
  @override
  Future<Map<String, Object?>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (fail) throw StateError('disk');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class FakeMaintenanceRepository() implements VehicleMaintenanceRepository {
  Garage data = Garage(
    asOf: DateTime(2026, 10, 25),
    vehicles: [Vehicle(id: 'v', name: 'Test car', manufactured: DateTime(2020), unit: 'mi')],
  );
  ServiceRecord? saved;
  AppFailure? error;
  @override
  Garage get snapshot => data;
  @override
  bool get offline => false;
  @override
  Stream<Garage> get changes => const Stream.empty();
  @override
  String newId() => 'new';
  @override
  Future<String> saveService(ServiceRecord service, {ServiceRecord? expected}) async {
    if (error != null) throw error!;
    saved = service;
    return service.id;
  }

  @override
  Future<void> open(String account) async {}
  @override
  Future<void> clearAccount() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> archive(String id, bool archived) async {}
  @override
  Future<void> deleteService(String id) async {}
  @override
  Future<String> saveVehicle(Vehicle vehicle, {int? initialMileage, Vehicle? expected}) async =>
      vehicle.id;
  @override
  Future<String> saveItem(MaintenanceItem item, {MaintenanceItem? expected}) async => item.id;
}
