import 'package:shared/model.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> list();

  Future<void> create({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  });

  Future<void> update(String id, {required String name, required DateTime manufactureDate});

  Future<void> delete(String id);
}
