import 'dart:async';

import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/domain/vehicle.dart';

class FakeVehicleRepo implements VehicleRepo {
  void reset() {
    listCompleter = Completer();
    createCompleter = Completer();
  }

  var listCompleter = Completer<List<Vehicle>>();
  var createCompleter = Completer<void>();

  var listCalls = 0;

  @override
  Future<List<Vehicle>> listVehicles() {
    listCalls++;
    return listCompleter.future;
  }

  final created = <Vehicle>[];

  @override
  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    created.add(
      Vehicle(
        'vehicle-${created.length}',
        name: name,
        manufactureDate: manufactureDate,
        distanceUnit: distanceUnit,
      ),
    );

    await createCompleter.future;
    return created.last;
  }
}
