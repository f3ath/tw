import 'package:shared/api.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/data/api_client.dart';

class BackendVehicleRepo(final ApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> listVehicles() async {
    final r = await _client.fetchCollection('vehicles');
    return r.collection.map((it) => it.toVehicle()).toList();
  }

  @override
  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    final response = await _client.createNew(
      'vehicles',
      attributes: {
        'name': name,
        'manufacture_date': manufactureDate.toIso8601String().split('T').first,
        'distance_unit': distanceUnit.name,
      },
    );
    return response.resource.toVehicle();
  }
}
