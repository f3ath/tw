import 'dart:async';

import 'package:tw_app/application/vehicle_repo.dart';
import 'package:tw_app/domain/vehicle.dart';

class FakeVehicleRepo implements VehicleRepo {
  void reset() {
    completer = Completer<List<Vehicle>>();
  }

  var completer = Completer<List<Vehicle>>();

  var listCalls = 0;

  @override
  Future<List<Vehicle>> listVehicles() {
    listCalls++;
    return completer.future;
  }
}
