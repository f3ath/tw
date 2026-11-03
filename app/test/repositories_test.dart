import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/local_repositories.dart';
import 'package:app/data/services/garage_codec.dart';
import 'package:app/data/services/services.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/policies.dart';
import 'package:app/domain/session_use_case.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 25);
  late MemoryStorage storage;
  late LocalMaintenanceRepository repo;
  var id = 0;
  setUp(() {
    storage = MemoryStorage();
    repo = LocalMaintenanceRepository(
      storage,
      DemoSimulation(delay: Duration.zero),
      clock: () => now,
      idGenerator: () => 'new-${id++}',
    );
  });
  test('auth persistence, account scoping, sign out removes maintenance cache', () async {
    final auth = LocalAuthRepository(
      storage,
      const MockAuthService(),
      DemoSimulation(delay: Duration.zero),
    );
    final session = SessionUseCase(auth, repo);
    await session.signIn();
    final restored = LocalAuthRepository(
      storage,
      const MockAuthService(),
      DemoSimulation(delay: Duration.zero),
    );
    await restored.restore();
    expect(restored.identity, auth.identity);
    await repo.saveVehicle(
      Vehicle(
        'own',
        name: 'My car',
        manufactureDate: DateTime(2020),
        distanceUnit: DistanceUnit.mi,
      ),
      initialMileage: 10,
    );
    await repo.open('another');
    expect(repo.snapshot.vehicles.any((v) => v.id == 'own'), isFalse);
    await repo.open(auth.identity!);
    expect(repo.snapshot.vehicles.any((v) => v.id == 'own'), isTrue);
    await session.signOut();
    expect(auth.identity, isNull);
    expect(repo.snapshot.vehicles, isEmpty);
    expect(storage.values.containsKey('garage.alex@torquewrench.demo'), isFalse);
  });
  test('atomic initial reading, immutable snapshots and failure leaves cache intact', () async {
    await repo.open('a');
    final old = repo.snapshot;
    storage.fail = true;
    await expectLater(
      repo.saveVehicle(
        Vehicle('v', name: 'New', manufactureDate: DateTime(2020), distanceUnit: DistanceUnit.km),
        initialMileage: 20,
      ),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.persistence)),
    );
    expect(identical(old, repo.snapshot), isTrue);
    storage.fail = false;
    await repo.saveVehicle(
      Vehicle('v', name: 'New', manufactureDate: DateTime(2020), distanceUnit: DistanceUnit.km),
      initialMileage: 20,
    );
    expect(repo.snapshot.history('v'), hasLength(1));
    expect(repo.snapshot.operationsFor(repo.snapshot.history('v').single.id), isEmpty);
    expect(old.vehicles, hasLength(2));
    expect(() => repo.snapshot.vehicles.clear(), throwsUnsupportedError);
  });
  test('mileage-only, linked save/edit/delete recalculation, rename and archive restore', () async {
    await repo.open('a');
    const policy = SchedulingPolicy();
    expect(policy.due(repo.snapshot, 'runner'), hasLength(5));
    await repo.saveService(
      Service('new', vehicleId: 'runner', date: now, odometer: 92000, details: ''),
    );
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 91000);
    await repo.saveService(
      Service('new', vehicleId: 'runner', date: now, odometer: 92000, details: ''),
      operations: [
        const Operation('new-oil', serviceId: 'new', scheduleId: 'oil', name: 'Oil', details: ''),
        const Operation('new-custom', serviceId: 'new', name: 'Oil', details: ''),
      ],
    );
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 97000);
    await repo.saveItem(
      const Schedule(
        id: 'oil',
        vehicleId: 'runner',
        name: 'Renamed oil',
        intervalDistance: 5000,
        intervalMonths: 6,
        details: '',
      ),
    );
    expect(repo.snapshot.operationsFor('new').first.name, 'Renamed oil');
    expect(
      repo.snapshot
          .operationsFor('new')
          .singleWhere((operation) => operation.scheduleId == null)
          .name,
      'Oil',
    );
    await repo.archive('oil', true);
    expect(policy.due(repo.snapshot, 'runner').any((d) => d.item.id == 'oil'), isFalse);
    await expectLater(
      repo.saveService(
        Service('bad', vehicleId: 'runner', date: now, odometer: 92000, details: ''),
        operations: [
          const Operation('bad-oil', serviceId: 'bad', scheduleId: 'oil', name: 'Oil', details: ''),
        ],
      ),
      throwsA(isA<AppFailure>()),
    );
    await repo.saveService(
      Service('new', vehicleId: 'runner', date: now, odometer: 92000, details: ''),
      operations: [
        const Operation('new-oil', serviceId: 'new', scheduleId: 'oil', name: 'Oil', details: ''),
      ],
    );
    await repo.archive('oil', false);
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 97000);
    await repo.deleteService('new');
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 91000);
    for (final s in repo.snapshot.history('runner')) {
      await repo.deleteService(s.id);
    }
    expect(repo.snapshot.estimate('runner'), isNull);
  });
  test('persistence serialization roundtrip, offline frozen as-of, settings', () async {
    await repo.open('a');
    final snapshot = repo.snapshot;
    final encoded = const GarageCodec().encode(snapshot);
    expect(const GarageCodec().encode(const GarageCodec().decode(encoded)), encoded);
    final offline = LocalMaintenanceRepository(
      storage,
      DemoSimulation(offline: true, delay: Duration.zero),
      clock: () => now.add(const Duration(days: 20)),
      idGenerator: () => 'x',
    );
    await offline.open('a');
    expect(offline.snapshot.asOf, now);
    await expectLater(
      offline.deleteService('r2'),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.connectivity)),
    );
    await expectLater(offline.open('unknown'), throwsA(isA<AppFailure>()));
    final settings = LocalSettingsRepository(storage);
    expect(await settings.load(), 'http://localhost:8080/api/v0');
    await settings.save('https://example.test');
    expect(await LocalSettingsRepository(storage).load(), 'https://example.test');
    await expectLater(settings.save('file:///x'), throwsA(isA<AppFailure>()));
  });
  test(
    'stale writes retain committed version while refresh does not create false conflicts',
    () async {
      await repo.open('a');
      final original = repo.snapshot.item('oil');
      await repo.refresh();
      await repo.saveItem(
        const Schedule(
          id: 'oil',
          vehicleId: 'runner',
          name: 'Changed',
          intervalDistance: 6000,
          details: '',
          intervalMonths: null,
        ),
        expected: original,
      );
      await expectLater(
        repo.saveItem(original, expected: original),
        throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.conflict)),
      );
      expect(repo.snapshot.item('oil').name, 'Changed');
    },
  );
  test(
    'operation-only stale edits are rejected and failed saves leave operations intact',
    () async {
      await repo.open('a');
      final service = repo.snapshot.service('r1');
      final originalOperations = repo.snapshot.operationsFor(service.id);
      final edited = [
        for (final operation in originalOperations)
          operation.scheduleId != null
              ? operation
              : Operation(
                  operation.id,
                  serviceId: service.id,
                  name: operation.name,
                  details: 'Changed details',
                ),
      ];
      final snapshot = repo.snapshot;
      storage.fail = true;
      await expectLater(repo.saveService(service, operations: edited), throwsA(isA<AppFailure>()));
      expect(repo.snapshot, same(snapshot));
      storage.fail = false;
      await repo.saveService(service, operations: edited);
      await expectLater(
        repo.saveService(
          service,
          operations: originalOperations,
          expected: service,
          expectedOperations: originalOperations,
        ),
        throwsA(isA<AppFailure>().having((failure) => failure.kind, 'kind', FailureKind.conflict)),
      );
      expect(repo.snapshot.operationsFor(service.id).last.details, 'Changed details');
      await repo.deleteService(service.id);
      expect(repo.snapshot.operationsFor(service.id), isEmpty);
      expect(snapshot.operationsFor(service.id), hasLength(3));
    },
  );

  test('legacy caches migrate links and custom strings to stable operation IDs', () {
    final legacy = <String, Object?>{
      'asOf': now.toIso8601String(),
      'vehicles': [
        {'id': 'v', 'name': 'Car', 'date': '2020-01-01T00:00:00.000', 'unit': 'km'},
      ],
      'items': [
        {
          'id': 'oil',
          'vehicle': 'v',
          'description': 'Oil',
          'distance': 5000,
          'months': null,
          'archived': true,
        },
      ],
      'services': [
        {
          'id': 's',
          'vehicle': 'v',
          'date': '2024-01-15T00:00:00.000',
          'mileage': 100,
          'links': ['oil'],
          'custom': ['Wash car', 'Wash car'],
        },
      ],
    };
    const codec = GarageCodec();
    final migrated = codec.decode(legacy);
    expect(migrated.vehicle('v').distanceUnit, DistanceUnit.km);
    expect(migrated.service('s').odometer, 100);
    expect(migrated.item('oil').isArchived, isTrue);
    final operations = migrated.operationsFor('s');
    expect(operations, hasLength(3));
    expect(operations.first.scheduleId, 'oil');
    expect(operations.first.name, 'Oil');
    expect(
      operations
          .where((operation) => operation.scheduleId == null)
          .map((operation) => operation.name),
      ['Wash car', 'Wash car'],
    );
    expect(operations.map((operation) => operation.id).toSet(), hasLength(3));
    expect(
      codec.decode(legacy).operations.map((operation) => operation.id),
      operations.map((operation) => operation.id),
    );
    final encoded = codec.encode(migrated);
    expect(encoded['version'], 2);
    expect(codec.encode(codec.decode(encoded)), encoded);
  });

  test('operation names and details round-trip independently of service fields', () async {
    await repo.open('a');
    final service = repo.snapshot.service('r1');
    final operations = [
      const Operation('custom-details', serviceId: 'r1', name: 'Wash car', details: 'Hand wash'),
      const Operation(
        'linked-details',
        serviceId: 'r1',
        scheduleId: 'oil',
        name: 'Ignored snapshot',
        details: 'Ignored snapshot',
      ),
    ];
    await repo.saveService(service, operations: operations);
    final oldItem = repo.snapshot.item('oil');
    await repo.saveItem(
      Schedule(
        id: oldItem.id,
        vehicleId: oldItem.vehicleId,
        name: 'Engine oil',
        details: 'Use specified oil',
        intervalDistance: oldItem.intervalDistance,
        intervalMonths: oldItem.intervalMonths,
      ),
    );
    const codec = GarageCodec();
    final restored = codec.decode(codec.encode(repo.snapshot));
    final custom = restored.operations.singleWhere((operation) => operation.id == 'custom-details');
    final linked = restored.operations.singleWhere((operation) => operation.id == 'linked-details');
    expect(custom.name, 'Wash car');
    expect(custom.details, 'Hand wash');
    expect(linked.name, 'Engine oil');
    expect(linked.details, 'Use specified oil');
  });
}
