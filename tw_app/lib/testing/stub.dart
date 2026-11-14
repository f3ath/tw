import 'dart:async';

import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';

class InMemoryAuthService({required final User _user}) implements AuthService {
  @override
  Future<User> login({
    Duration pollInterval = const Duration(seconds: 1),
    Duration pollTimeout = const Duration(seconds: 10),
  }) async => _user;

  @override
  Future<void> logout() async {}
}

class InMemoryVehicleRepo({Iterable<Vehicle> initialVehicles = const []}) implements VehicleRepo {
  final vehicles = <String, Vehicle>{for (final vehicle in initialVehicles) vehicle.id: vehicle};
  var listCalls = 0;

  Future<void>? _nextList;
  Future<void>? _nextCreate;
  Future<void>? _nextDelete;

  Completer<void> pauseNextList() {
    final c = Completer<void>();
    _nextList = c.future;
    return c;
  }

  Completer<void> pauseNextCreate() {
    final c = Completer<void>();
    _nextCreate = c.future;
    return c;
  }

  Completer<void> pauseNextDelete() {
    final c = Completer<void>();
    _nextDelete = c.future;
    return c;
  }

  @override
  Future<void> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    final pending = _nextCreate;
    _nextCreate = null;
    await pending;
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
    final pending = _nextList;
    _nextList = null;
    await pending;
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
    final pending = _nextDelete;
    _nextDelete = null;
    await pending;
    if (vehicles.remove(id) == null) throw StateError('Invalid id');
  }
}
