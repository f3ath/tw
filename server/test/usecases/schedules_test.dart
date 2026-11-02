import 'package:shared/api.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  late TestHarness harness;
  late TwApiClient client;
  late Vehicle vehicle;

  setUp(() async {
    harness = TestHarness();
    await harness.startServer();
    client = await harness.login();
    vehicle = await client.createVehicle(name: 'Civic', manufactureDate: DateTime(2020));
  });

  tearDown(() async {
    await harness.stopServer();
  });

  Future<Schedule> createSchedule() =>
      client.createSchedule(vehicle.id, name: 'Oil', intervalDistance: 5000, intervalMonths: 6);

  test('a new vehicle has an empty schedule', () async {
    expect(await client.listSchedules(vehicle.id), isEmpty);
  });

  const intervals = <({String label, int? distance, int? months})>[
    (label: 'distance only', distance: 5000, months: null),
    (label: 'time only', distance: null, months: 6),
    (label: 'distance and time', distance: 5000, months: 6),
  ];
  for (final unit in DistanceUnit.values) {
    for (final interval in intervals) {
      test('create and list a ${unit.name} schedule with ${interval.label}', () async {
        final target = await client.createVehicle(
          name: 'Corolla',
          manufactureDate: DateTime(2020),
          distanceUnit: unit,
        );
        final created = await client.createSchedule(
          target.id,
          name: 'Engine oil and filter',
          intervalDistance: interval.distance,
          intervalMonths: interval.months,
        );
        expect(created.id, isNotEmpty);
        expect(created.vehicleId, target.id);
        expect(created.name, 'Engine oil and filter');
        expect(created.intervalDistance, interval.distance);
        expect(created.intervalMonths, interval.months);
        expect(created.isArchived, isFalse);

        final listed = (await client.listSchedules(target.id)).single;
        expect(listed.id, created.id);
        expect(listed.vehicleId, target.id);
        expect(listed.name, created.name);
        expect(listed.intervalDistance, interval.distance);
        expect(listed.intervalMonths, interval.months);
        expect(listed.isArchived, isFalse);
        expect(await client.listSchedules(vehicle.id), isEmpty);
      });
    }
  }

  test('save edited description and intervals on the same schedule item', () async {
    final created = await createSchedule();
    final updated = await client.updateSchedule(
      vehicle.id,
      created.id,
      name: 'Engine oil and filter',
      intervalDistance: 10000,
      intervalMonths: 12,
    );
    expect(updated, isNotNull);
    expect(updated!.id, created.id);
    expect(updated.vehicleId, vehicle.id);
    expect(updated.name, 'Engine oil and filter');
    expect(updated.intervalDistance, 10000);
    expect(updated.intervalMonths, 12);
    final listed = (await client.listSchedules(vehicle.id)).single;
    expect(listed.id, created.id);
    expect(listed.name, updated.name);
    expect(listed.intervalDistance, updated.intervalDistance);
    expect(listed.intervalMonths, updated.intervalMonths);
  });

  for (final interval in intervals.take(2)) {
    test('switch an existing combined interval to ${interval.label}', () async {
      final created = await createSchedule();
      final updated = await client.updateSchedule(
        vehicle.id,
        created.id,
        name: created.name,
        intervalDistance: interval.distance,
        intervalMonths: interval.months,
      );
      expect(updated, isNotNull);
      expect(updated!.intervalDistance, interval.distance);
      expect(updated.intervalMonths, interval.months);
      final listed = (await client.listSchedules(vehicle.id)).single;
      expect(listed.id, created.id);
      expect(listed.intervalDistance, interval.distance);
      expect(listed.intervalMonths, interval.months);
    });
  }

  test('archive and restore preserve the item ID, description, and intervals', () async {
    final created = await createSchedule();
    for (final isArchived in [true, false]) {
      final updated = await client.updateSchedule(
        vehicle.id,
        created.id,
        name: created.name,
        intervalDistance: created.intervalDistance,
        intervalMonths: created.intervalMonths,
        isArchived: isArchived,
      );
      expect(updated, isNotNull);
      expect(updated!.isArchived, isArchived);
      final listed = (await client.listSchedules(vehicle.id)).single;
      expect(listed.id, created.id);
      expect(listed.vehicleId, vehicle.id);
      expect(listed.name, created.name);
      expect(listed.intervalDistance, created.intervalDistance);
      expect(listed.intervalMonths, created.intervalMonths);
      expect(listed.isArchived, isArchived);
    }
  });

  test('schedules persist across sessions for the same account', () async {
    final created = await createSchedule();
    final email = (await client.fetchCurrentUser())!.email;
    await client.deleteSession();
    final restored = await harness.login(email: email);
    final listed = (await restored.listSchedules(vehicle.id)).single;
    expect(listed.id, created.id);
    expect(listed.name, created.name);
    expect(listed.intervalDistance, created.intervalDistance);
    expect(listed.intervalMonths, created.intervalMonths);
  });

  for (final isPending in [false, true]) {
    test('schedules require ${isPending ? 'completed sign-in' : 'authentication'}', () async {
      final unauthorized = harness.newClient();
      if (isPending) await unauthorized.createSession();
      await expectLater(unauthorized.listSchedules(vehicle.id), throwsStatusCode(401));
      await expectLater(
        unauthorized.createSchedule(
          vehicle.id,
          name: 'Oil',
          intervalDistance: 5000,
          intervalMonths: 6,
        ),
        throwsStatusCode(401),
      );
      await expectLater(
        unauthorized.updateSchedule(
          vehicle.id,
          const Uuid().v4(),
          name: 'Oil',
          intervalDistance: 5000,
          intervalMonths: 6,
          isArchived: true,
        ),
        throwsStatusCode(401),
      );
      expect(await client.listSchedules(vehicle.id), isEmpty);
    });
  }

  test("users cannot list, create, edit, or archive another user's schedule", () async {
    final other = await harness.login();
    await expectLater(other.listSchedules(vehicle.id), throwsStatusCode(404));
    await expectLater(
      other.createSchedule(vehicle.id, name: 'Oil', intervalDistance: 5000, intervalMonths: 6),
      throwsStatusCode(404),
    );
    final created = await createSchedule();
    await expectLater(
      other.updateSchedule(
        vehicle.id,
        created.id,
        name: 'Changed',
        intervalDistance: 10000,
        intervalMonths: 12,
        isArchived: true,
      ),
      throwsStatusCode(404),
    );
    final unchanged = (await client.listSchedules(vehicle.id)).single;
    expect(unchanged.name, created.name);
    expect(unchanged.intervalDistance, created.intervalDistance);
    expect(unchanged.intervalMonths, created.intervalMonths);
    expect(unchanged.isArchived, isFalse);
  });

  test('missing vehicles and schedule items return not found', () async {
    final missingId = const Uuid().v4();
    await expectLater(client.listSchedules(missingId), throwsStatusCode(404));
    await expectLater(
      client.createSchedule(missingId, name: 'Oil', intervalDistance: 5000, intervalMonths: 6),
      throwsStatusCode(404),
    );
    await expectLater(
      client.updateSchedule(
        vehicle.id,
        missingId,
        name: 'Oil',
        intervalDistance: 5000,
        intervalMonths: 6,
      ),
      throwsStatusCode(404),
    );
  });

  for (final name in ['', '   ']) {
    test('reject a blank description on creation (${name.length} characters)', () async {
      await expectLater(
        client.createSchedule(vehicle.id, name: name, intervalDistance: 5000, intervalMonths: 6),
        throwsStatusCode(400),
      );
      expect(await client.listSchedules(vehicle.id), isEmpty);
    });

    test('reject a blank description on editing (${name.length} characters)', () async {
      final created = await createSchedule();
      await expectLater(
        client.updateSchedule(
          vehicle.id,
          created.id,
          name: name,
          intervalDistance: 5000,
          intervalMonths: 6,
        ),
        throwsStatusCode(400),
      );
      expect((await client.listSchedules(vehicle.id)).single.name, created.name);
    });
  }

  const invalidIntervals = <({String label, int? distance, int? months})>[
    (label: 'no interval', distance: null, months: null),
    (label: 'zero distance', distance: 0, months: 6),
    (label: 'negative distance', distance: -1, months: 6),
    (label: 'zero months', distance: 5000, months: 0),
    (label: 'negative months', distance: 5000, months: -1),
  ];
  for (final interval in invalidIntervals) {
    test('reject ${interval.label} on creation', () async {
      await expectLater(
        client.createSchedule(
          vehicle.id,
          name: 'Oil',
          intervalDistance: interval.distance,
          intervalMonths: interval.months,
        ),
        throwsStatusCode(400),
      );
      expect(await client.listSchedules(vehicle.id), isEmpty);
    });

    test('reject ${interval.label} on editing without changing the item', () async {
      final created = await createSchedule();
      await expectLater(
        client.updateSchedule(
          vehicle.id,
          created.id,
          name: 'Changed',
          intervalDistance: interval.distance,
          intervalMonths: interval.months,
        ),
        throwsStatusCode(400),
      );
      final unchanged = (await client.listSchedules(vehicle.id)).single;
      expect(unchanged.name, created.name);
      expect(unchanged.intervalDistance, created.intervalDistance);
      expect(unchanged.intervalMonths, created.intervalMonths);
    });
  }
}
