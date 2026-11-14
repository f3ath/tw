import 'dart:async';

import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/app/service_repo.dart';

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
  Future<void>? _nextUpdate;
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

  Completer<void> pauseNextUpdate() {
    final completer = Completer<void>();
    _nextUpdate = completer.future;
    return completer;
  }

  Completer<void> pauseNextDelete() {
    final c = Completer<void>();
    _nextDelete = c.future;
    return c;
  }

  @override
  Future<void> create({
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
  Future<List<Vehicle>> list() async {
    listCalls++;
    final pending = _nextList;
    _nextList = null;
    await pending;
    return vehicles.values.toList();
  }

  @override
  Future<void> update(String id, {required String name, required DateTime manufactureDate}) async {
    final pending = _nextUpdate;
    _nextUpdate = null;
    await pending;
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
  Future<void> delete(String id) async {
    final pending = _nextDelete;
    _nextDelete = null;
    await pending;
    if (vehicles.remove(id) == null) throw StateError('Invalid id');
  }
}

class InMemoryScheduleRepo({Iterable<Schedule> initialSchedules = const []})
    implements ScheduleRepo {
  final schedules = <String, Schedule>{
    for (final schedule in initialSchedules) schedule.id: schedule,
  };
  var listCalls = 0;
  Future<void>? _nextList;
  Future<void>? _nextCreate;
  Future<void>? _nextUpdate;
  Future<void>? _nextDelete;
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

  Completer<void> pauseNextDelete() {
    final completer = Completer<void>();
    _nextDelete = completer.future;
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

  @override
  Future<void> delete(String scheduleId) async {
    final pending = _nextDelete;
    _nextDelete = null;
    await pending;
    if (schedules.remove(scheduleId) == null) throw StateError('Schedule not found');
  }
}

class InMemoryServiceRepo({Iterable<Service> initialServices = const []}) implements ServiceRepo {
  final services = <String, Service>{for (final service in initialServices) service.id: service};
  var listCalls = 0;
  var updateCalls = 0;
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
  Future<List<Service>> list(String vehicleId) async {
    listCalls++;
    final pending = _nextList;
    _nextList = null;
    await pending;
    return services.values.where((service) => service.vehicleId == vehicleId).toList();
  }

  @override
  Future<void> create(
    String vehicleId, {
    required DateTime date,
    required int odometer,
    String details = '',
  }) async {
    final pending = _nextCreate;
    _nextCreate = null;
    await pending;
    String id;
    do {
      id = 'service-${_nextId++}';
    } while (services.containsKey(id));
    services[id] = Service(
      id,
      vehicleId: vehicleId,
      date: date,
      odometer: odometer,
      details: details,
    );
  }

  @override
  Future<void> update(
    String serviceId, {
    required DateTime date,
    required int odometer,
    required String details,
  }) async {
    updateCalls++;
    final pending = _nextUpdate;
    _nextUpdate = null;
    await pending;
    final original = services[serviceId];
    if (original == null) throw StateError('Service not found');
    services[serviceId] = Service(
      original.id,
      vehicleId: original.vehicleId,
      date: date,
      odometer: odometer,
      details: details,
    );
  }
}
