import 'dart:async';

import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/app/schedules_repo.dart';

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
  var _nextId = 0;

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
    String id;
    do {
      id = 'vehicle-${_nextId++}';
    } while (vehicles.containsKey(id));
    final v = Vehicle(id, name: name, manufactureDate: manufactureDate, distanceUnit: distanceUnit);
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

class InMemorySchedulesRepo({Iterable<Schedule> initialSchedules = const []})
    implements SchedulesRepo {
  final schedules = <String, Schedule>{
    for (final schedule in initialSchedules) schedule.id: schedule,
  };
  var listCalls = 0;
  Future<void>? _nextList;
  Future<void>? _nextCreate;
  Future<void>? _nextUpdate;
  var _nextId = 0;

  Completer<void> pauseNextList() {
    final completer = Completer<void>();
    _nextList = completer.future;
    return completer;
  }

  Completer<void> pauseNextCreate() {
    final completer = Completer<void>();
    _nextCreate = completer.future;
    return completer;
  }

  Completer<void> pauseNextUpdate() {
    final completer = Completer<void>();
    _nextUpdate = completer.future;
    return completer;
  }

  @override
  Future<List<Schedule>> list(String vehicleId) async {
    listCalls++;
    final pending = _nextList;
    _nextList = null;
    await pending;
    return schedules.values.where((schedule) => schedule.vehicleId == vehicleId).toList();
  }

  @override
  Future<void> create(
    String vehicleId, {
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  }) async {
    final pending = _nextCreate;
    _nextCreate = null;
    await pending;
    String id;
    do {
      id = 'schedule-${_nextId++}';
    } while (schedules.containsKey(id));
    schedules[id] = Schedule(
      id: id,
      vehicleId: vehicleId,
      name: name,
      intervalDistance: intervalDistance,
      intervalMonths: intervalMonths,
      details: details,
    );
  }

  @override
  Future<void> update(
    String scheduleId, {
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    required String details,
  }) async {
    final pending = _nextUpdate;
    _nextUpdate = null;
    await pending;
    final original = schedules[scheduleId];
    if (original == null) throw StateError('Schedule not found');
    schedules[scheduleId] = Schedule(
      id: original.id,
      vehicleId: original.vehicleId,
      name: name,
      intervalDistance: intervalDistance,
      intervalMonths: intervalMonths,
      details: details,
      isArchived: original.isArchived,
    );
  }
}
