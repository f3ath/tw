import 'dart:async';

import 'package:shared/model.dart';
import 'package:shared/time.dart';
import 'package:app/app/auth_service.dart';
import 'package:app/app/create_conflict.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/app/operation_repo.dart';
import 'package:app/testing/request_gate.dart';

class InMemoryAuthService({required final User _user}) implements AuthService {
  @override
  Future<User?> restoreSession() async => null;

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
  final createIds = <String>[];
  var listCalls = 0;

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
    required String id,
    required String name,
    required CalendarDate manufactureDate,
    required MileageUnit mileageUnit,
  }) async {
    createIds.add(id);
    await _createGate.wait();
    if (vehicles.containsKey(id)) throw const CreateConflict();
    final v = Vehicle(id, name: name, manufactureDate: manufactureDate, mileageUnit: mileageUnit);
    vehicles[v.id] = v;
  }

  @override
  Future<List<Vehicle>> list() async {
    listCalls++;
    await _listGate.wait();
    return vehicles.values.toList();
  }

  @override
  Future<void> update(
    String id, {
    required String name,
    required CalendarDate manufactureDate,
    MileageUnit? mileageUnit,
  }) async {
    await _updateGate.wait();
    final v = vehicles[id];
    if (v == null) {
      throw StateError('Vehicle not found');
    }
    vehicles[id] = Vehicle(
      id,
      name: name,
      manufactureDate: manufactureDate,
      mileageUnit: mileageUnit ?? v.mileageUnit,
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
  final createIds = <String>[];
  var listCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();

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
    required String id,
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  }) async {
    createIds.add(id);
    await _createGate.wait();
    if (schedules.containsKey(id)) throw const CreateConflict();
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
  final createIds = <String>[];
  Map<String, Operation>? _operations;
  var listCalls = 0;
  var updateCalls = 0;
  var deleteCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();

  Completer<void> pauseNextList() => _listGate.pause();

  Completer<void> pauseNextCreate() => _createGate.pause();

  Completer<void> pauseNextUpdate() => _updateGate.pause();

  Completer<void> pauseNextDelete() => _deleteGate.pause();

  @override
  Future<List<Service>> list(String vehicleId) async {
    listCalls++;
    await _listGate.wait();
    final vehicleServices = services.values.where((service) => service.vehicleId == vehicleId);
    final operations = _operations;
    if (operations == null) return vehicleServices.toList();

    final operationsByService = <String, List<Operation>>{};
    for (final operation in operations.values) {
      (operationsByService[operation.serviceId] ??= []).add(operation);
    }
    return vehicleServices.map((service) {
      final operations = operationsByService[service.id] ?? const <Operation>[];
      if (operations.isEmpty && service.operations.isEmpty) return service;
      return Service(
        service.id,
        vehicleId: service.vehicleId,
        date: service.date,
        odometer: service.odometer,
        details: service.details,
        operations: List.unmodifiable(operations),
      );
    }).toList();
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
    required String id,
    required CalendarDate date,
    required int odometer,
    String details = '',
  }) async {
    createIds.add(id);
    await _createGate.wait();
    if (services.containsKey(id)) throw const CreateConflict();
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
    required CalendarDate date,
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
      operations: original.operations,
    );
  }
}

class InMemoryOperationRepo({
  Iterable<Operation> initialOperations = const [],
  InMemoryServiceRepo? serviceRepo,
  InMemoryScheduleRepo? scheduleRepo,
}) implements OperationRepo {
  this {
    if (serviceRepo != null) serviceRepo._operations = operations;
  }

  final _serviceRepo = serviceRepo ?? InMemoryServiceRepo();
  final _scheduleRepo = scheduleRepo ?? InMemoryScheduleRepo();
  final operations = <String, Operation>{
    for (final operation in initialOperations) operation.id: operation,
  };
  final createIds = <String>[];
  var listCalls = 0;
  final _listGate = RequestGate();
  final _createGate = RequestGate();
  final _updateGate = RequestGate();
  final _deleteGate = RequestGate();

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
  Future<void> create(
    String serviceId, {
    required String id,
    required String name,
    String details = '',
  }) async {
    createIds.add(id);
    await _createGate.wait();
    _addOperation(serviceId, id: id, name: name, details: details);
  }

  @override
  Future<void> createFromSchedule(
    String serviceId, {
    required String id,
    required String scheduleId,
    String details = '',
  }) async {
    createIds.add(id);
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
      (operation) =>
          operation.id != id &&
          operation.serviceId == serviceId &&
          operation.scheduleId == scheduleId,
    )) {
      throw Exception('Schedule already recorded in this service');
    }
    _addOperation(
      serviceId,
      id: id,
      name: schedule.name,
      details: details,
      scheduleId: schedule.id,
    );
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
    required String id,
    required String name,
    required String details,
    String? scheduleId,
  }) {
    if (operations.containsKey(id)) throw const CreateConflict();
    operations[id] = Operation(
      id,
      serviceId: serviceId,
      name: name,
      details: details,
      scheduleId: scheduleId,
    );
  }
}
