import 'package:shared/model.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> listVehicles();

  Future<void> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  });

  Future<void> updateVehicle(
    String id, {
    required String name,
    required DateTime manufactureDate,
  });
}
