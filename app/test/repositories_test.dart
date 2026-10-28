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
      Vehicle(id: 'own', name: 'My car', manufactured: DateTime(2020), unit: 'mi'),
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
        Vehicle(id: 'v', name: 'New', manufactured: DateTime(2020), unit: 'km'),
        initialMileage: 20,
      ),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.persistence)),
    );
    expect(identical(old, repo.snapshot), isTrue);
    storage.fail = false;
    await repo.saveVehicle(
      Vehicle(id: 'v', name: 'New', manufactured: DateTime(2020), unit: 'km'),
      initialMileage: 20,
    );
    expect(repo.snapshot.history('v'), hasLength(1));
    expect(repo.snapshot.history('v').single.links, isEmpty);
    expect(old.vehicles, hasLength(2));
    expect(() => repo.snapshot.vehicles.clear(), throwsUnsupportedError);
  });
  test('mileage-only, linked save/edit/delete recalculation, rename and archive restore', () async {
    await repo.open('a');
    const policy = SchedulingPolicy();
    expect(policy.due(repo.snapshot, 'runner'), hasLength(5));
    await repo.saveService(
      ServiceRecord(id: 'new', vehicleId: 'runner', date: now, mileage: 92000),
    );
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 91000);
    await repo.saveService(
      ServiceRecord(
        id: 'new',
        vehicleId: 'runner',
        date: now,
        mileage: 92000,
        links: ['oil'],
        custom: ['Oil'],
      ),
    );
    expect(policy.calculate(repo.snapshot, repo.snapshot.item('oil')).distanceDue, 97000);
    await repo.saveItem(
      const MaintenanceItem(
        id: 'oil',
        vehicleId: 'runner',
        description: 'Renamed oil',
        distance: 5000,
        months: 6,
      ),
    );
    expect(
      repo.snapshot.item(repo.snapshot.service('new').links.single).description,
      'Renamed oil',
    );
    expect(repo.snapshot.service('new').custom.single, 'Oil');
    await repo.archive('oil', true);
    expect(policy.due(repo.snapshot, 'runner').any((d) => d.item.id == 'oil'), isFalse);
    await expectLater(
      repo.saveService(
        ServiceRecord(id: 'bad', vehicleId: 'runner', date: now, mileage: 92000, links: ['oil']),
      ),
      throwsA(isA<AppFailure>()),
    );
    await repo.saveService(
      ServiceRecord(id: 'new', vehicleId: 'runner', date: now, mileage: 92000, links: ['oil']),
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
        const MaintenanceItem(
          id: 'oil',
          vehicleId: 'runner',
          description: 'Changed',
          distance: 6000,
        ),
        expected: original,
      );
      await expectLater(
        repo.saveItem(original, expected: original),
        throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.conflict)),
      );
      expect(repo.snapshot.item('oil').description, 'Changed');
    },
  );
}
