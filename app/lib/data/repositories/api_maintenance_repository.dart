import 'dart:async';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../../domain/repositories.dart';
import '../services/api_maintenance_service.dart';
import '../services/garage_codec.dart';
import '../services/services.dart';
import 'local_repositories.dart' show storage, stale;

class ApiMaintenanceRepository(
  final ApiMaintenanceService service,
  final LocalPersistenceService persistence, {
  required final DateTime Function() clock,
}) implements VehicleMaintenanceRepository {
  final _events = StreamController<Garage>.broadcast(sync: true);
  final _validation = const ValidationPolicy();
  final _codec = const GarageCodec();
  Garage _data = Garage(asOf: DateTime(2000));
  String? _cacheKey;
  bool _offline = false;
  bool _writing = false;
  int _sequence = 0;

  @override
  Garage get snapshot => _data;
  @override
  Stream<Garage> get changes => _events.stream;
  @override
  bool get offline => _offline;
  @override
  String newId() => 'draft-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  void _publish(Garage data) {
    _data = data;
    _events.add(data);
  }

  @override
  Future<void> open(String account) async {
    final key = 'api.garage.${service.cacheScope}';
    if (_cacheKey != key) {
      _cacheKey = key;
      _offline = false;
      _publish(Garage(asOf: DateTime(2000)));
    }
    try {
      await refresh();
    } on AppFailure catch (failure) {
      if (failure.kind != FailureKind.connectivity) rethrow;
      final cached = await storage(() => persistence.read(key));
      if (cached == null) rethrow;
      final data = await storage(() async => _codec.decode(cached));
      if (_cacheKey != key) return;
      _offline = true;
      _publish(data);
    }
  }

  @override
  Future<void> refresh() async {
    final key = _cacheKey;
    if (key == null) return;
    try {
      final data = await service.load(clock());
      if (_cacheKey != key) return;
      _offline = false;
      // A cache failure must not hide data that was successfully read from the server.
      _publish(data);
      await storage(() => persistence.write(key, _codec.encode(data)));
    } on AppFailure catch (failure) {
      if (_cacheKey == key && failure.kind == FailureKind.connectivity) {
        _offline = true;
        _events.add(_data);
      }
      rethrow;
    }
  }

  @override
  Future<void> clearAccount() async {
    final key = _cacheKey;
    if (key != null) await storage(() => persistence.remove(key));
    _cacheKey = null;
    _offline = false;
    _publish(Garage(asOf: DateTime(2000)));
  }

  Future<T> _write<T>(Future<T> Function() change) async {
    if (_cacheKey == null) throw const AppFailure(FailureKind.missing, 'Sign in to continue.');
    if (_offline) {
      throw const AppFailure(FailureKind.connectivity, 'Connect and refresh before saving.');
    }
    if (_writing) throw const AppFailure(FailureKind.conflict, 'Another save is pending. Retry.');
    _writing = true;
    try {
      // Re-read before checking the form's original values for stale edits.
      await refresh();
      final result = await change();
      await refresh();
      return result;
    } finally {
      _writing = false;
    }
  }

  @override
  Future<String> saveVehicle(
    Vehicle value, {
    int? initialMileage,
    Vehicle? expected,
  }) => _write(() async {
    final id = value.id;
    final existing = _data.vehicles.where((vehicle) => vehicle.id == id).firstOrNull;
    if (expected != null && (existing == null || !sameVehicle(existing, expected))) stale();
    _validation.vehicle(_data, value, clock());
    if (existing != null) {
      if (existing.distanceUnit != value.distanceUnit) invalid('Distance unit is fixed.', 'unit');
      await service.updateVehicle(value);
      return id;
    }
    if (initialMileage == null || initialMileage < 0) {
      invalid('Enter a nonnegative whole odometer reading.', 'mileage');
    }
    final created = await service.createVehicle(value);
    await service.createService(
      Service('', vehicleId: created.id, date: day(clock()), odometer: initialMileage, details: ''),
    );
    return created.id;
  });

  @override
  Future<String> saveItem(Schedule value, {Schedule? expected}) => _write(() async {
    final id = value.id;
    final existing = _data.items.where((item) => item.id == id).firstOrNull;
    if (expected != null && (existing == null || !sameItem(existing, expected))) stale();
    _validation.item(value);
    if (existing == null) {
      final created = await service.createSchedule(value);
      return created.id;
    }
    await service.updateSchedule(value);
    return id;
  });

  @override
  Future<void> archive(String id, bool archived) => _write(() async {
    await service.updateSchedule(_data.item(id).withArchive(archived));
  });

  @override
  Future<String> saveService(
    Service value, {
    Iterable<Operation> operations = const [],
    Service? expected,
    Iterable<Operation>? expectedOperations,
  }) {
    final desired = List<Operation>.of(operations);
    return _write(() async {
      final id = value.id;
      final existing = _data.services.where((record) => record.id == id).firstOrNull;
      if (expected != null && (existing == null || !sameService(existing, expected))) stale();
      final previous = _data.operationsFor(id);
      if (expectedOperations != null && !sameOperations(previous, expectedOperations)) stale();
      _validation.service(_data, value, clock(), operations: desired);
      final savedId = existing == null ? (await service.createService(value)).id : id;
      if (existing != null) await service.updateService(value);
      final keep = desired.map((operation) => operation.id).toSet();
      for (final operation in previous.where((operation) => !keep.contains(operation.id))) {
        await service.deleteOperation(operation.id);
      }
      for (final operation in desired) {
        final original = previous.where((op) => op.id == operation.id).firstOrNull;
        if (original == null) {
          await service.createOperation(savedId, operation);
        } else if (!sameOperation(original, operation)) {
          await service.updateOperation(operation);
        }
      }
      return savedId;
    });
  }

  @override
  Future<void> deleteService(String id) => _write(() => service.deleteService(id));
}
