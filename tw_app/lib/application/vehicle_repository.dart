import 'package:tw_app/domain/vehicle.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> listVehicles();
}
