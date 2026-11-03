import 'models.dart';

abstract interface class AuthRepository() {
  String? get identity;
  Future<void> restore();
  Future<void> signIn();
  Future<void> signOut();
}

abstract interface class SettingsRepository() {
  Future<String> load();
  Future<void> save(String address);
}

abstract interface class VehicleMaintenanceRepository() {
  Garage get snapshot;
  bool get offline;
  Stream<Garage> get changes;
  Future<void> open(String account);
  Future<void> clearAccount();
  Future<void> refresh();
  Future<String> saveVehicle(Vehicle vehicle, {int? initialMileage, Vehicle? expected});
  Future<String> saveItem(Schedule item, {Schedule? expected});
  Future<void> archive(String id, bool archived);
  Future<String> saveService(
    Service service, {
    Iterable<Operation> operations = const [],
    Service? expected,
    Iterable<Operation>? expectedOperations,
  });
  Future<void> deleteService(String id);
  String newId();
}
