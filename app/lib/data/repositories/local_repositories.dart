import 'dart:async';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import '../../domain/repositories.dart';
import '../services/services.dart';
import '../services/garage_codec.dart';

Future<T> storage<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppFailure {
    rethrow;
  } catch (_) {
    throw const AppFailure(
      FailureKind.persistence,
      'Could not save or read local data. Please retry.',
    );
  }
}

class LocalAuthRepository(
  final LocalPersistenceService persistence,
  final AuthenticationService auth,
  final Simulation simulation,
) implements AuthRepository {
  @override
  String? identity;
  @override
  Future<void> restore() async {
    identity = (await storage(() => persistence.read('session')))?['identity'] as String?;
  }

  @override
  Future<void> signIn() async {
    if (simulation.offline) {
      throw const AppFailure(FailureKind.connectivity, 'Connect to simulate sign-in.');
    }
    await simulation.wait();
    final user = await auth.authenticate();
    await storage(() => persistence.write('session', {'identity': user}));
    identity = user;
  }

  @override
  Future<void> signOut() async {
    await storage(() => persistence.remove('session'));
    identity = null;
  }
}

class LocalSettingsRepository(final LocalPersistenceService persistence)
    implements SettingsRepository {
  @override
  Future<String> load() async {
    final address = (await storage(() => persistence.read('settings')))?['address'] as String?;
    if (address == 'http://localhost:8080') {
      await save('http://localhost:8080/api/v0');
      return 'http://localhost:8080/api/v0';
    }
    return address ?? 'http://localhost:8080/api/v0';
  }

  @override
  Future<void> save(String address) async {
    final uri = Uri.tryParse(address);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      invalid('Enter an absolute HTTP or HTTPS address.', 'address');
    }
    await storage(() => persistence.write('settings', {'address': address}));
  }
}

class LocalMaintenanceRepository(
  final LocalPersistenceService persistence,
  final Simulation simulation, {
  required final DateTime Function() clock,
  required final String Function() idGenerator,
  final bool emptySeed = false,
}) implements VehicleMaintenanceRepository {
  final _events = StreamController<Garage>.broadcast(sync: true);
  final _validation = const ValidationPolicy();
  final _codec = const GarageCodec();
  String? _account;
  bool _writing = false;
  Garage _data = Garage(asOf: DateTime(2000));
  @override
  Garage get snapshot => _data;
  @override
  Stream<Garage> get changes => _events.stream;
  @override
  bool get offline => simulation.offline;
  @override
  String newId() => idGenerator();
  @override
  Future<void> open(String account) async {
    if (_account != account) {
      _data = Garage(asOf: DateTime(2000));
      _account = null;
    }
    await simulation.wait();
    final raw = await storage(() => persistence.read('garage.$account'));
    if (raw == null && offline) {
      throw const AppFailure(
        FailureKind.connectivity,
        'No saved data available. Connect and retry.',
      );
    }
    final data = raw == null
        ? seed(clock(), empty: emptySeed)
        : await storage(() async => _codec.decode(raw));
    _account = account;
    _data = offline ? data : data.copy(asOf: clock());
    if (!offline) await storage(() => persistence.write('garage.$account', _codec.encode(_data)));
    _events.add(_data);
  }

  @override
  Future<void> refresh() async {
    if (_account != null) await open(_account!);
  }

  @override
  Future<void> clearAccount() async {
    if (_account != null) await storage(() => persistence.remove('garage.$_account'));
    _account = null;
    _data = Garage(asOf: DateTime(2000));
    _events.add(_data);
  }

  Future<T> _commit<T>((Garage, T) Function(Garage) change) async {
    if (_account == null) throw const AppFailure(FailureKind.missing, 'Sign in to continue.');
    if (_writing) throw const AppFailure(FailureKind.conflict, 'Another save is pending. Retry.');
    _writing = true;
    try {
      await simulation.wait(write: true);
      final (next, result) = change(_data);
      final saved = next.copy(asOf: clock());
      await storage(() => persistence.write('garage.$_account', _codec.encode(saved)));
      _data = saved;
      _events.add(_data);
      return result;
    } finally {
      _writing = false;
    }
  }

  @override
  Future<String> saveVehicle(Vehicle vehicle, {int? initialMileage, Vehicle? expected}) =>
      _commit((data) {
        if (expected != null && !sameVehicle(data.vehicle(vehicle.id), expected)) stale();
        _validation.vehicle(data, vehicle, clock());
        final exists = data.vehicles.any((v) => v.id == vehicle.id);
        if (exists && data.vehicle(vehicle.id).unit != vehicle.unit) {
          invalid('Distance unit is fixed.', 'unit');
        }
        if (!exists && (initialMileage == null || initialMileage < 0)) {
          invalid('Enter a nonnegative whole odometer reading.', 'mileage');
        }
        return (
          data.copy(
            vehicles: [...data.vehicles.where((v) => v.id != vehicle.id), vehicle],
            services: [
              ...data.services,
              if (!exists)
                ServiceRecord(
                  id: newId(),
                  vehicleId: vehicle.id,
                  date: day(clock()),
                  mileage: initialMileage!,
                ),
            ],
          ),
          vehicle.id,
        );
      });
  @override
  Future<String> saveItem(MaintenanceItem item, {MaintenanceItem? expected}) => _commit((data) {
    data.vehicle(item.vehicleId);
    if (expected != null && !sameItem(data.item(item.id), expected)) stale();
    _validation.item(item);
    return (data.copy(items: [...data.items.where((i) => i.id != item.id), item]), item.id);
  });
  @override
  Future<void> archive(String id, bool archived) async {
    await _commit(
      (data) => (
        data.copy(items: [for (final i in data.items) i.id == id ? i.withArchive(archived) : i]),
        data.item(id).id,
      ),
    );
  }

  @override
  Future<String> saveService(ServiceRecord service, {ServiceRecord? expected}) => _commit((data) {
    if (expected != null && !sameService(data.service(service.id), expected)) stale();
    _validation.service(data, service, clock());
    return (
      data.copy(services: [...data.services.where((s) => s.id != service.id), service]),
      service.id,
    );
  });
  @override
  Future<void> deleteService(String id) async {
    await _commit((data) {
      data.service(id);
      return (data.copy(services: data.services.where((s) => s.id != id)), id);
    });
  }
}

Garage seed(DateTime now, {bool empty = false}) {
  final today = day(now);
  if (empty) return Garage(asOf: now);
  return Garage(
    asOf: now,
    vehicles: [
      Vehicle(id: 'runner', name: '4Runner', manufactured: calendarAdd(today, -734), unit: 'mi'),
      Vehicle(id: 'santa', name: 'Santa Fe', manufactured: calendarAdd(today, -156), unit: 'km'),
    ],
    items: [
      const MaintenanceItem(
        id: 'oil',
        vehicleId: 'runner',
        description: 'Engine oil & filter',
        distance: 5000,
        months: 6,
      ),
      const MaintenanceItem(
        id: 'brakes',
        vehicleId: 'runner',
        description: 'Brake fluid',
        months: 24,
      ),
      const MaintenanceItem(
        id: 'tires',
        vehicleId: 'runner',
        description: 'Tire rotation',
        distance: 92000,
      ),
      const MaintenanceItem(
        id: 'cabin',
        vehicleId: 'runner',
        description: 'Cabin air filter',
        months: 25,
      ),
      const MaintenanceItem(
        id: 'air',
        vehicleId: 'runner',
        description: 'Engine air filter',
        distance: 92140,
      ),
      const MaintenanceItem(
        id: 'archived',
        vehicleId: 'runner',
        description: 'Wiper inspection',
        months: 3,
        archived: true,
      ),
      const MaintenanceItem(
        id: 'santa-oil',
        vehicleId: 'santa',
        description: 'Engine oil & filter',
        distance: 91000,
        months: 6,
      ),
      const MaintenanceItem(
        id: 'santa-cabin',
        vehicleId: 'santa',
        description: 'Cabin air filter',
        months: 6,
      ),
    ],
    services: [
      ServiceRecord(
        id: 'r1',
        vehicleId: 'runner',
        date: calendarAdd(today, -200),
        mileage: 86000,
        links: ['oil', 'archived'],
        custom: ['Replace wiper blades'],
      ),
      ServiceRecord(id: 'r2', vehicleId: 'runner', date: calendarAdd(today, -5), mileage: 91240),
      ServiceRecord(id: 's1', vehicleId: 'santa', date: calendarAdd(today, -9), mileage: 90480),
    ],
  );
}

Never stale() => throw const AppFailure(
  FailureKind.conflict,
  'Record changed. Your edits are retained. Go back and reopen the record to reload, or review your changes.',
);
