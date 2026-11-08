import 'package:tw_app/domain/vehicle.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> listVehicles();
}
