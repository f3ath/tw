import 'package:shared/api.dart';
import 'package:tw_app/app/vehicle_repo.dart';

class BackendVehicleRepo(final TwApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> list() => _client.listVehicles();

  @override
  Future<void> create({
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
  Future<void> update(String id, {required String name, required DateTime manufactureDate}) async {
    await _client.updateVehicle(id, name: name, manufactureDate: manufactureDate);
  }

  @override
  Future<void> delete(String id) => _client.deleteVehicle(id);
}
