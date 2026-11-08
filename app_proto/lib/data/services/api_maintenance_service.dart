import '../../domain/models.dart';
import 'api_auth_service.dart';

class ApiMaintenanceService(final ApiAuthService auth) {
  String get cacheScope => auth.cacheScope;

  Future<Garage> load(DateTime asOf) => auth.withClient((client) async {
    final vehicles = await client.listVehicles();
    final schedules = <Schedule>[];
    final services = <Service>[];
    final operations = <Operation>[];
    for (final vehicle in vehicles) {
      schedules.addAll(await client.listSchedules(vehicle.id));
      final records = await client.listServices(vehicle.id);
      services.addAll(records);
      for (final service in records) {
        operations.addAll(await client.listOperations(service.id));
      }
    }
    return Garage(
      asOf: asOf,
      vehicles: vehicles,
      items: schedules,
      services: services,
      operations: operations,
    );
  });

  Future<Vehicle> createVehicle(Vehicle value) => auth.withClient(
    (client) => client.createVehicle(
      name: value.name,
      manufactureDate: value.manufactureDate,
      distanceUnit: value.distanceUnit,
    ),
  );
  Future<void> updateVehicle(Vehicle value) => auth.withClient((client) async {
    await client.updateVehicle(value.id, name: value.name, manufactureDate: value.manufactureDate);
  });
  Future<void> deleteVehicle(String id) => auth.withClient((client) => client.deleteVehicle(id));
  Future<Schedule> createSchedule(Schedule value) => auth.withClient(
    (client) => client.createSchedule(
      value.vehicleId,
      name: value.name,
      intervalDistance: value.intervalDistance,
      intervalMonths: value.intervalMonths,
      details: value.details,
    ),
  );
  Future<void> updateSchedule(Schedule value) => auth.withClient((client) async {
    await client.updateSchedule(
      value.id,
      name: value.name,
      intervalDistance: value.intervalDistance,
      intervalMonths: value.intervalMonths,
      details: value.details,
      isArchived: value.isArchived,
    );
  });
  Future<Service> createService(Service value) => auth.withClient(
    (client) => client.createService(
      value.vehicleId,
      date: value.date,
      odometer: value.odometer,
      details: value.details,
    ),
  );
  Future<void> updateService(Service value) => auth.withClient((client) async {
    await client.updateService(
      value.id,
      date: value.date,
      odometer: value.odometer,
      details: value.details,
    );
  });
  Future<void> deleteService(String id) => auth.withClient((client) => client.deleteService(id));
  Future<Operation> createOperation(String serviceId, Operation value) => auth.withClient(
    (client) => client.createOperation(
      serviceId,
      scheduleId: value.scheduleId,
      name: value.scheduleId == null ? value.name : null,
      details: value.scheduleId == null ? value.details : null,
    ),
  );
  Future<void> updateOperation(Operation value) => auth.withClient((client) async {
    await client.updateOperation(
      value.id,
      scheduleId: value.scheduleId,
      name: value.scheduleId == null ? value.name : null,
      details: value.scheduleId == null ? value.details : null,
    );
  });
  Future<void> deleteOperation(String id) =>
      auth.withClient((client) => client.deleteOperation(id));
}
