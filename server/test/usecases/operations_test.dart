import 'package:shared/api.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/time.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  final harness = TestHarness();
  late TwApiClient client;
  late Vehicle vehicle;
  late Service service;
  late Schedule schedule;

  setUp(() async {
    await harness.startServer();
    client = await harness.login();
    vehicle = await client.createVehicle(name: 'Civic', manufactureDate: DateTime(2020));
    service = await client.createService(vehicle.id, date: DateTime(2024, 1, 15), odometer: 150);
    schedule = await client.createSchedule(
      vehicle.id,
      name: 'Oil',
      details: 'Use the specified engine oil',
      intervalDistance: 5000,
      intervalMonths: 6,
    );
  });

  tearDown(() async {
    await harness.stopServer();
  });

  Future<void> archive(bool isArchived) async {
    await client.updateSchedule(
      schedule.id,
      name: schedule.name,
      intervalDistance: schedule.intervalDistance,
      intervalMonths: schedule.intervalMonths,
      isArchived: isArchived,
    );
  }

  test('a service can have no operations', () async {
    expect(await client.listOperations(service.id), isEmpty);
  });

  test('create and list a scheduled operation', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    expect(created.id, isNotEmpty);
    expect(created.serviceId, service.id);
    expect(created.scheduleId, schedule.id);
    expect(created.name, schedule.name);
    expect(created.details, schedule.details);
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.id, created.id);
    expect(listed.serviceId, service.id);
    expect(listed.scheduleId, schedule.id);
    expect(listed.name, schedule.name);
    expect(listed.details, schedule.details);
  });

  test('create and list a custom operation', () async {
    final created = await client.createOperation(
      service.id,
      name: 'Replace wiper blades',
      details: 'Front and rear',
    );
    expect(created.id, isNotEmpty);
    expect(created.serviceId, service.id);
    expect(created.scheduleId, isNull);
    expect(created.name, 'Replace wiper blades');
    expect(created.details, 'Front and rear');
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.id, created.id);
    expect(listed.serviceId, service.id);
    expect(listed.scheduleId, isNull);
    expect(listed.name, created.name);
    expect(listed.details, created.details);
  });

  test('multiple scheduled and custom operations belong to the same service', () async {
    final brakes = await client.createSchedule(vehicle.id, name: 'Brakes', intervalMonths: 24);
    final oil = await client.createOperation(service.id, scheduleId: schedule.id);
    final brake = await client.createOperation(service.id, scheduleId: brakes.id);
    final wipers = await client.createOperation(service.id, name: 'Replace wipers');
    final wash = await client.createOperation(service.id, name: 'Wash car');
    final listed = await client.listOperations(service.id);
    expect(
      listed.map((operation) => operation.id),
      unorderedEquals([oil.id, brake.id, wipers.id, wash.id]),
    );
    expect(
      listed
          .where((operation) => operation.scheduleId != null)
          .map((operation) => operation.scheduleId),
      unorderedEquals([schedule.id, brakes.id]),
    );
    expect(
      listed.where((operation) => operation.scheduleId == null).map((operation) => operation.name),
      unorderedEquals(['Replace wipers', 'Wash car']),
    );
  });

  test('list operations only for the selected service', () async {
    final second = await client.createService(
      vehicle.id,
      date: DateTime(2024, 1, 16),
      odometer: 200,
    );
    final firstOperation = await client.createOperation(service.id, name: 'Replace wipers');
    final secondOperation = await client.createOperation(second.id, name: 'Wash car');
    expect((await client.listOperations(service.id)).single.id, firstOperation.id);
    expect((await client.listOperations(second.id)).single.id, secondOperation.id);
  });

  test('the same schedule can be completed in different services', () async {
    final first = await client.createOperation(service.id, scheduleId: schedule.id);
    final secondService = await client.createService(
      vehicle.id,
      date: DateTime(2024, 1, 16),
      odometer: 200,
    );
    final second = await client.createOperation(secondService.id, scheduleId: schedule.id);
    expect(second.id, isNot(first.id));
    expect((await client.listOperations(service.id)).single.scheduleId, schedule.id);
    expect((await client.listOperations(secondService.id)).single.scheduleId, schedule.id);
  });

  test('edit a custom operation without changing its ID or service', () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    final updated = await client.updateOperation(
      created.id,
      name: 'Replace wipers',
      details: 'Replace the rear blade',
    );
    expect(updated, isNotNull);
    expect(updated!.id, created.id);
    expect(updated.serviceId, service.id);
    expect(updated.scheduleId, isNull);
    expect(updated.name, 'Replace wipers');
    expect(updated.details, 'Replace the rear blade');
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.name, 'Replace wipers');
    expect(listed.details, 'Replace the rear blade');
  });

  test('editing can replace custom text with a schedule link and back', () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    final linked = await client.updateOperation(created.id, scheduleId: schedule.id);
    expect(linked!.id, created.id);
    expect(linked.scheduleId, schedule.id);
    expect(linked.name, schedule.name);
    expect((await client.listOperations(service.id)).single.scheduleId, schedule.id);
    final custom = await client.updateOperation(created.id, name: 'Replace wipers');
    expect(custom!.id, created.id);
    expect(custom.scheduleId, isNull);
    expect(custom.name, 'Replace wipers');
    expect((await client.listOperations(service.id)).single.scheduleId, isNull);
  });

  test('editing can replace a schedule link with another active item', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    final brakes = await client.createSchedule(vehicle.id, name: 'Brakes', intervalMonths: 24);
    final updated = await client.updateOperation(created.id, scheduleId: brakes.id);
    expect(updated!.id, created.id);
    expect(updated.scheduleId, brakes.id);
    expect(updated.name, brakes.name);
    expect((await client.listOperations(service.id)).single.scheduleId, brakes.id);
  });

  test('delete an operation without deleting its service, schedule, or other operations', () async {
    final linked = await client.createOperation(service.id, scheduleId: schedule.id);
    final custom = await client.createOperation(service.id, name: 'Wash car');
    await client.deleteOperation(linked.id);
    expect((await client.listOperations(service.id)).single.id, custom.id);
    expect((await client.listServices(vehicle.id)).single.id, service.id);
    expect((await client.listSchedules(vehicle.id)).single.id, schedule.id);
    await client.deleteOperation(custom.id);
    expect(await client.listOperations(service.id), isEmpty);
    expect((await client.listServices(vehicle.id)).single.id, service.id);
  });

  test('deleting a service removes its operations and preserves the schedule', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    await client.deleteService(service.id);
    await expectLater(client.listOperations(service.id), throwsStatusCode(404));
    await expectLater(client.updateOperation(created.id, name: 'Wash car'), throwsStatusCode(404));
    await expectLater(client.deleteOperation(created.id), throwsStatusCode(404));
    expect((await client.listSchedules(vehicle.id)).single.id, schedule.id);
  });

  test('operations persist across sessions for the same account', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    final email = (await client.fetchCurrentUser())!.email;
    await client.deleteCurrentSession();
    final restored = await harness.login(email: email);
    final listed = (await restored.listOperations(service.id)).single;
    expect(listed.id, created.id);
    expect(listed.serviceId, service.id);
    expect(listed.scheduleId, schedule.id);
    expect(listed.name, schedule.name);
    expect(listed.details, schedule.details);
  });

  test('scheduled names and details follow schedule edits; custom fields stay unchanged', () async {
    final linked = await client.createOperation(service.id, scheduleId: schedule.id);
    final custom = await client.createOperation(
      service.id,
      name: schedule.name,
      details: schedule.details,
    );
    await client.updateSchedule(
      schedule.id,
      name: 'Engine oil and filter',
      details: 'Replace the filter as well',
      intervalDistance: 10000,
      intervalMonths: 12,
    );
    final listed = await client.listOperations(service.id);
    final updated = listed.singleWhere((operation) => operation.id == linked.id);
    expect(updated.scheduleId, schedule.id);
    expect(updated.name, 'Engine oil and filter');
    expect(updated.details, 'Replace the filter as well');
    expect(listed.singleWhere((operation) => operation.id == custom.id).name, schedule.name);
    expect(listed.singleWhere((operation) => operation.id == custom.id).details, schedule.details);
  });

  test('custom text matching a schedule does not create a link or a new schedule', () async {
    final created = await client.createOperation(service.id, name: schedule.name);
    expect(created.scheduleId, isNull);
    expect((await client.listOperations(service.id)).single.scheduleId, isNull);
    expect((await client.listSchedules(vehicle.id)).single.id, schedule.id);
  });

  test('duplicate custom descriptions are allowed', () async {
    final first = await client.createOperation(service.id, name: 'Wash car');
    final second = await client.createOperation(service.id, name: 'Wash car');
    expect(second.id, isNot(first.id));
    expect((await client.listOperations(service.id)).map((operation) => operation.name), [
      'Wash car',
      'Wash car',
    ]);
  });

  test('each schedule item can be selected only once per service', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    await expectLater(
      client.createOperation(service.id, scheduleId: schedule.id),
      throwsStatusCode(400),
    );
    expect((await client.listOperations(service.id)).single.id, created.id);
  });

  test('editing cannot duplicate another operation schedule selection', () async {
    await client.createOperation(service.id, scheduleId: schedule.id);
    final custom = await client.createOperation(service.id, name: 'Wash car');
    await expectLater(
      client.updateOperation(custom.id, scheduleId: schedule.id),
      throwsStatusCode(400),
    );
    final listed = await client.listOperations(service.id);
    expect(listed, hasLength(2));
    expect(listed.singleWhere((operation) => operation.id == custom.id).name, 'Wash car');
  });

  test(
    'saving the same schedule link excludes the operation itself from duplicate checks',
    () async {
      final created = await client.createOperation(service.id, scheduleId: schedule.id);
      final updated = await client.updateOperation(created.id, scheduleId: schedule.id);
      expect(updated!.id, created.id);
      expect((await client.listOperations(service.id)).single.id, created.id);
    },
  );

  test('archive and restore preserve historical operation links and identity', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    for (final isArchived in [true, false]) {
      await archive(isArchived);
      final listed = (await client.listOperations(service.id)).single;
      expect(listed.id, created.id);
      expect(listed.serviceId, service.id);
      expect(listed.scheduleId, schedule.id);
      expect(listed.name, schedule.name);
      expect(listed.details, schedule.details);
      expect((await client.listSchedules(vehicle.id)).single.isArchived, isArchived);
    }
  });

  test('existing archived links can be retained or removed while editing', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    await archive(true);
    final retained = await client.updateOperation(created.id, scheduleId: schedule.id);
    expect(retained!.scheduleId, schedule.id);
    await client.updateService(service.id, date: DateTime(2024, 1, 16), odometer: 200);
    expect((await client.listOperations(service.id)).single.id, created.id);
    await client.deleteOperation(created.id);
    expect(await client.listOperations(service.id), isEmpty);
  });

  for (final isToday in [false, true]) {
    test(
      'reject newly selected archived items for ${isToday ? 'today' : 'past service dates'}',
      () async {
        await archive(true);
        if (isToday) {
          final now = systemClock();
          await client.updateService(
            service.id,
            date: DateTime(now.year, now.month, now.day),
            odometer: 150,
          );
        }
        await expectLater(
          client.createOperation(service.id, scheduleId: schedule.id),
          throwsStatusCode(400),
        );
        expect(await client.listOperations(service.id), isEmpty);
      },
    );
  }

  test('editing cannot add a newly selected archived item', () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    await archive(true);
    await expectLater(
      client.updateOperation(created.id, scheduleId: schedule.id),
      throwsStatusCode(400),
    );
    final unchanged = (await client.listOperations(service.id)).single;
    expect(unchanged.scheduleId, isNull);
    expect(unchanged.name, 'Wash car');
  });

  test('restored schedules can be selected in a new service', () async {
    await archive(true);
    await archive(false);
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    expect(created.scheduleId, schedule.id);
  });

  for (final isForeignAccount in [false, true]) {
    for (final isEditing in [false, true]) {
      test(
        'reject schedules from another ${isForeignAccount ? 'account' : 'vehicle'} on ${isEditing ? 'editing' : 'creation'}',
        () async {
          final owner = isForeignAccount ? await harness.login() : client;
          final otherVehicle = await owner.createVehicle(
            name: 'Corolla',
            manufactureDate: DateTime(2020),
          );
          final otherSchedule = await owner.createSchedule(
            otherVehicle.id,
            name: 'Brakes',
            intervalMonths: 24,
          );
          final existing = isEditing
              ? await client.createOperation(service.id, name: 'Wash car')
              : null;
          await expectLater(
            existing == null
                ? client.createOperation(service.id, scheduleId: otherSchedule.id)
                : client.updateOperation(existing.id, scheduleId: otherSchedule.id),
            throwsStatusCode(400),
          );
          final listed = await client.listOperations(service.id);
          expect(listed, hasLength(isEditing ? 1 : 0));
          if (isEditing) expect(listed.single.name, 'Wash car');
        },
      );
    }
  }

  for (final isPending in [false, true]) {
    test('operation CRUD requires ${isPending ? 'completed sign-in' : 'authentication'}', () async {
      final unauthorized = harness.newClient();
      if (isPending) await unauthorized.createSession();
      final id = const Uuid().v4();
      await expectLater(unauthorized.listOperations(service.id), throwsStatusCode(401));
      await expectLater(
        unauthorized.createOperation(service.id, name: 'Wash car'),
        throwsStatusCode(401),
      );
      await expectLater(unauthorized.updateOperation(id, name: 'Wash car'), throwsStatusCode(401));
      await expectLater(unauthorized.deleteOperation(id), throwsStatusCode(401));
    });
  }

  test("users cannot list, add, edit, or delete another user's operations", () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    final other = await harness.login();
    await expectLater(other.listOperations(service.id), throwsStatusCode(404));
    await expectLater(
      other.createOperation(service.id, name: 'Replace wipers'),
      throwsStatusCode(404),
    );
    await expectLater(other.updateOperation(created.id, name: 'Changed'), throwsStatusCode(404));
    await expectLater(other.deleteOperation(created.id), throwsStatusCode(404));
    expect((await client.listOperations(service.id)).single.name, 'Wash car');
  });

  test('editing an operation preserves its original service', () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    final second = await client.createService(
      vehicle.id,
      date: DateTime(2024, 1, 16),
      odometer: 200,
    );
    final updated = await client.updateOperation(created.id, name: 'Changed');
    expect(updated!.serviceId, service.id);
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.id, created.id);
    expect(listed.serviceId, service.id);
    expect(listed.name, 'Changed');
    expect(await client.listOperations(second.id), isEmpty);
  });

  test('missing services and operations return not found', () async {
    final id = const Uuid().v4();
    await expectLater(client.listOperations(id), throwsStatusCode(404));
    await expectLater(client.createOperation(id, name: 'Wash car'), throwsStatusCode(404));
    await expectLater(client.updateOperation(id, name: 'Wash car'), throwsStatusCode(404));
    await expectLater(client.deleteOperation(id), throwsStatusCode(404));
  });

  for (final isEditing in [false, true]) {
    test('reject a missing schedule reference on ${isEditing ? 'editing' : 'creation'}', () async {
      final existing = isEditing
          ? await client.createOperation(service.id, name: 'Wash car')
          : null;
      final missingId = const Uuid().v4();
      await expectLater(
        existing == null
            ? client.createOperation(service.id, scheduleId: missingId)
            : client.updateOperation(existing.id, scheduleId: missingId),
        throwsStatusCode(400),
      );
    });
  }

  for (final isEditing in [false, true]) {
    for (final isName in [true, false]) {
      test(
        'scheduled operation ${isName ? 'name' : 'details'} is read-only on ${isEditing ? 'editing' : 'creation'}',
        () async {
          final existing = isEditing
              ? await client.createOperation(service.id, scheduleId: schedule.id)
              : null;
          await expectLater(
            existing == null
                ? client.createOperation(
                    service.id,
                    scheduleId: schedule.id,
                    name: isName ? 'Override' : null,
                    details: isName ? null : 'Override',
                  )
                : client.updateOperation(
                    existing.id,
                    scheduleId: schedule.id,
                    name: isName ? 'Override' : null,
                    details: isName ? null : 'Override',
                  ),
            throwsStatusCode(400),
          );
          final listed = await client.listOperations(service.id);
          expect(listed, hasLength(isEditing ? 1 : 0));
          if (isEditing) {
            expect(listed.single.name, schedule.name);
            expect(listed.single.details, schedule.details);
          }
        },
      );
    }
  }

  const invalidInputs = <({String label, String? name, bool isScheduled})>[
    (label: 'neither a schedule nor custom text', name: null, isScheduled: false),
    (label: 'an empty custom description', name: '', isScheduled: false),
    (label: 'a blank custom description', name: '   ', isScheduled: false),
    (label: 'both a schedule and custom text', name: 'Wash car', isScheduled: true),
  ];
  for (final input in invalidInputs) {
    for (final isEditing in [false, true]) {
      test('reject ${input.label} on ${isEditing ? 'editing' : 'creation'}', () async {
        final existing = isEditing
            ? await client.createOperation(service.id, name: 'Replace wipers')
            : null;
        final scheduleId = input.isScheduled ? schedule.id : null;
        await expectLater(
          existing == null
              ? client.createOperation(service.id, scheduleId: scheduleId, name: input.name)
              : client.updateOperation(existing.id, scheduleId: scheduleId, name: input.name),
          throwsStatusCode(400),
        );
        final listed = await client.listOperations(service.id);
        expect(listed, hasLength(isEditing ? 1 : 0));
        if (isEditing) expect(listed.single.name, 'Replace wipers');
      });
    }
  }

  test('concurrent selections cannot duplicate a schedule within a service', () async {
    final otherHarness = TestHarness();
    addTearDown(otherHarness.stopServer);
    await otherHarness.startServer();
    final email = (await client.fetchCurrentUser())!.email;
    final other = await otherHarness.login(email: email);
    final results = await Future.wait([
      client
          .createOperation(service.id, scheduleId: schedule.id)
          .then<Object>((value) => value, onError: (Object error) => error),
      other
          .createOperation(service.id, scheduleId: schedule.id)
          .then<Object>((value) => value, onError: (Object error) => error),
    ]);
    expect(results.whereType<Operation>(), hasLength(1));
    final failure = results.whereType<RequestFailure>().single;
    expect(failure.rawResponse.httpResponse.statusCode, 400);
    expect((await client.listOperations(service.id)).single.scheduleId, schedule.id);
  });
}
