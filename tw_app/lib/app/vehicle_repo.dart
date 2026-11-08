import 'package:tw_app/domain/vehicle.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> listVehicles();

  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  });
}
