import 'package:shared/api.dart';
import 'package:tw_app/app/vehicle_repo.dart';

class BackendVehicleRepo(final TwApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> listVehicles() => _client.listVehicles();

  @override
  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) => _client.createVehicle(
    name: name,
    manufactureDate: manufactureDate,
    distanceUnit: distanceUnit,
  );
}
