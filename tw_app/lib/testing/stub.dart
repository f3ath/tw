import 'dart:async';

import 'package:shared/model.dart';
import 'package:tw_app/app/auth_service.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/app/service_repo.dart';
import 'package:tw_app/app/operation_repo.dart';
import 'package:tw_app/testing/request_gate.dart';

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

  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();

  Completer<void> pauseNextList() => _listGate.pause();

  Completer<void> pauseNextCreate() => _createGate.pause();

  Completer<void> pauseNextUpdate() => _updateGate.pause();

  Completer<void> pauseNextDelete() => _deleteGate.pause();

  @override
  Future<void> create({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    await _createGate.wait();
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
    await _listGate.wait();
    return vehicles.values.toList();
  }

  @override
  Future<void> update(String id, {required String name, required DateTime manufactureDate}) async {
    await _updateGate.wait();
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
    await _deleteGate.wait();
    if (vehicles.remove(id) == null) throw StateError('Invalid id');
  }
}

class InMemoryScheduleRepo({Iterable<Schedule> initialSchedules = const []})
    implements ScheduleRepo {
  final schedules = <String, Schedule>{
    for (final schedule in initialSchedules) schedule.id: schedule,
  };
  var listCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();
  var _nextId = 0;

  Completer<void> pauseNextList() => _listGate.pause();

  Completer<void> pauseNextCreate() => _createGate.pause();

  Completer<void> pauseNextUpdate() => _updateGate.pause();

  Completer<void> pauseNextDelete() => _deleteGate.pause();

  @override
  Future<List<Schedule>> list(String vehicleId) async {
    listCalls++;
    await _listGate.wait();
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
    await _createGate.wait();
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
    await _updateGate.wait();
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
    await _deleteGate.wait();
    if (schedules.remove(scheduleId) == null) throw StateError('Schedule not found');
  }
}

class InMemoryServiceRepo({Iterable<Service> initialServices = const []}) implements ServiceRepo {
  final services = <String, Service>{for (final service in initialServices) service.id: service};
  var listCalls = 0;
  var updateCalls = 0;
  var deleteCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();
  var _nextId = 0;

  Completer<void> pauseNextList() => _listGate.pause();

  Completer<void> pauseNextCreate() => _createGate.pause();

  Completer<void> pauseNextUpdate() => _updateGate.pause();

  Completer<void> pauseNextDelete() => _deleteGate.pause();

  @override
  Future<List<Service>> list(String vehicleId) async {
    listCalls++;
    await _listGate.wait();
    return services.values.where((service) => service.vehicleId == vehicleId).toList();
  }

  @override
  Future<void> delete(String serviceId) async {
    deleteCalls++;
    await _deleteGate.wait();
    if (services.remove(serviceId) == null) throw StateError('Service not found');
  }

  @override
  Future<Service> create(
    String vehicleId, {
    required DateTime date,
    required int odometer,
    String details = '',
  }) async {
    await _createGate.wait();
    String id;
    do {
      id = 'service-${_nextId++}';
    } while (services.containsKey(id));
    final service = Service(
      id,
      vehicleId: vehicleId,
      date: date,
      odometer: odometer,
      details: details,
    );
    services[id] = service;
    return service;
  }

  @override
  Future<void> update(
    String serviceId, {
    required DateTime date,
    required int odometer,
    required String details,
  }) async {
    updateCalls++;
    await _updateGate.wait();
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

class InMemoryOperationRepo({
  Iterable<Operation> initialOperations = const [],
  InMemoryServiceRepo? serviceRepo,
  InMemoryScheduleRepo? scheduleRepo,
}) implements OperationRepo {
  final _serviceRepo = serviceRepo ?? InMemoryServiceRepo();
  final _scheduleRepo = scheduleRepo ?? InMemoryScheduleRepo();
  final operations = <String, Operation>{
    for (final operation in initialOperations) operation.id: operation,
  };
  var listCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();
  var _nextId = 0;

  Completer<void> pauseNextList() => _listGate.pause();

  Completer<void> pauseNextCreate() => _createGate.pause();

  Completer<void> pauseNextUpdate() => _updateGate.pause();

  Completer<void> pauseNextDelete() => _deleteGate.pause();

  @override
  Future<List<Operation>> list(String serviceId) async {
    listCalls++;
    await _listGate.wait();
    return operations.values.where((operation) => operation.serviceId == serviceId).toList();
  }

  @override
  Future<void> create(String serviceId, {required String name, String details = ''}) async {
    await _createGate.wait();
    _addOperation(serviceId, name: name, details: details);
  }

  @override
  Future<void> createFromSchedule(
    String serviceId, {
    required String scheduleId,
    String details = '',
  }) async {
    await _createGate.wait();
    final service = _serviceRepo.services[serviceId];
    if (service == null) throw Exception('Service not found');
    final schedule = _scheduleRepo.schedules[scheduleId];
    if (schedule == null) throw Exception('Schedule not found');
    if (schedule.vehicleId != service.vehicleId) {
      throw Exception('Schedule belongs to another vehicle');
    }
    if (schedule.isArchived) throw Exception('Schedule is archived');
    if (operations.values.any(
      (operation) => operation.serviceId == serviceId && operation.scheduleId == scheduleId,
    )) {
      throw Exception('Schedule already recorded in this service');
    }
    _addOperation(serviceId, name: schedule.name, details: details, scheduleId: schedule.id);
  }

  @override
  Future<void> update(
    String operationId, {
    required String name,
    required String details,
    required String? scheduleId,
  }) async {
    await _updateGate.wait();
    final original = operations[operationId];
    if (original == null) throw Exception('Operation not found');
    if (scheduleId != null) {
      final service = _serviceRepo.services[original.serviceId];
      final schedule = _scheduleRepo.schedules[scheduleId];
      if (service == null || schedule == null || schedule.vehicleId != service.vehicleId) {
        throw Exception('Invalid schedule');
      }
      if (schedule.isArchived && scheduleId != original.scheduleId) {
        throw Exception('Schedule is archived');
      }
      if (operations.values.any(
        (operation) =>
            operation.id != operationId &&
            operation.serviceId == original.serviceId &&
            operation.scheduleId == scheduleId,
      )) {
        throw Exception('Schedule already recorded in this service');
      }
    }
    operations[operationId] = Operation(
      original.id,
      serviceId: original.serviceId,
      scheduleId: scheduleId,
      name: name,
      details: details,
    );
  }

  @override
  Future<void> delete(String operationId) async {
    await _deleteGate.wait();
    if (operations.remove(operationId) == null) throw Exception('Operation not found');
  }

  void _addOperation(
    String serviceId, {
    required String name,
    required String details,
    String? scheduleId,
  }) {
    String id;
    do {
      id = 'operation-${_nextId++}';
    } while (operations.containsKey(id));
    operations[id] = Operation(
      id,
      serviceId: serviceId,
      name: name,
      details: details,
      scheduleId: scheduleId,
    );
  }
}
