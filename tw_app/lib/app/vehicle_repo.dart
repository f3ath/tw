import 'package:shared/model.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> listVehicles();

  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  });
}
