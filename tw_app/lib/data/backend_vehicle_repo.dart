import 'package:shared/api.dart';
import 'package:tw_app/app/vehicle_repo.dart';

class BackendVehicleRepo(final TwApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> listVehicles() => _client.listVehicles();

  @override
  Future<void> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    await _client.createVehicle(
      name: name,
      manufactureDate: manufactureDate,
      distanceUnit: distanceUnit,
    );
  }

  @override
  Future<void> updateVehicle(
    String id, {
    required String name,
    required DateTime manufactureDate,
  }) async {
    await _client.updateVehicle(id, name: name, manufactureDate: manufactureDate);
  }
}
