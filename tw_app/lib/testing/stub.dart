import 'dart:async';

import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';

const user1 = User('user-0', name: 'Begelme Ashambe', email: 'begelme@example.com');

final vehicle1 = Vehicle(
  'vehicle-0',
  name: 'Santa Fe',
  manufactureDate: DateTime(2013),
  distanceUnit: .mi,
);
final vehicle2 = Vehicle(
  'vehicle-1',
  name: '4Runner',
  manufactureDate: DateTime(2022),
  distanceUnit: .mi,
);

final vehicles = [vehicle1, vehicle2];

class InMemoryAuthService({final User _user = user1}) implements AuthService {
  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 1),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => _user;

  @override
  Future<void> logout() async {}
}

class InMemoryVehicleRepo() implements VehicleRepo {
  final vehicles = <String, Vehicle>{vehicle1.id: vehicle1, vehicle2.id: vehicle2};
  var listCalls = 0;

  Future<void> _listFuture = Future.value();
  Future<void> _createFuture = Future.value();
  Future<void> _deleteFuture = Future.value();

  Completer<void> lockList() {
    final c = Completer<void>();
    _listFuture = c.future;
    return c;
  }

  Completer<void> lockCreate() {
    final c = Completer<void>();
    _createFuture = c.future;
    return c;
  }

  Completer<void> lockDelete() {
    final c = Completer<void>();
    _deleteFuture = c.future;
    return c;
  }

  @override
  Future<void> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    await _createFuture;
    final v = Vehicle(
      'vehicle-${vehicles.length}',
      name: name,
      manufactureDate: manufactureDate,
      distanceUnit: distanceUnit,
    );
    vehicles[v.id] = v;
  }

  @override
  Future<List<Vehicle>> listVehicles() async {
    listCalls++;
    await _listFuture;
    return vehicles.values.toList();
  }

  @override
  Future<void> updateVehicle(
    String id, {
    required String name,
    required DateTime manufactureDate,
  }) async {
    final v = vehicles[id];
    if (v == null) {
      throw StateError('Vehicle not found');
    }
    vehicles[id] = Vehicle(
      id,
      name: name,
      manufactureDate: manufactureDate,
      distanceUnit: v.distanceUnit,
    );
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await _deleteFuture;
    if (vehicles.remove(id) == null) throw StateError('Invalid id');
  }
}
