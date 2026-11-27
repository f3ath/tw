import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/resource_id.dart';
import 'package:test/test.dart';

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
    vehicle = await client.createVehicle(name: 'Civic', manufactureDate: CalendarDate(2020));
    service = await client.createService(
      vehicle.id,
      date: CalendarDate(2024, 1, 15),
      odometer: 150,
    );
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

  test('create and list the complete flow with explicit IDs', () async {
    final vehicleId = ResourceId.generate();
    final scheduleId = ResourceId.generate();
    final serviceId = ResourceId.generate();
    final linkedId = 'a${ResourceId.generate().substring(1)}';
    final customId = ResourceId.generate();
    final createdVehicle = await client.createVehicle(
      id: vehicleId,
      name: 'Corolla',
      manufactureDate: CalendarDate(2020),
    );
    final createdSchedule = await client.createSchedule(
      createdVehicle.id,
      id: scheduleId,
      name: 'Oil change',
      intervalMonths: 6,
    );
    final createdService = await client.createService(
      createdVehicle.id,
      id: serviceId,
      date: CalendarDate(2024, 1, 15),
      odometer: 150,
    );
    final linked = await client.createOperation(
      createdService.id.toUpperCase(),
      id: linkedId.toUpperCase(),
      scheduleId: createdSchedule.id.toUpperCase(),
    );
    final custom = await client.createOperation(
      createdService.id,
      id: customId,
      name: 'Replace wipers',
      details: 'Front and rear',
    );

    expect(createdVehicle.id, vehicleId);
    expect(createdSchedule.id, scheduleId);
    expect(createdService.id, serviceId);
    expect(linked.id, linkedId);
    expect(linked.serviceId, serviceId);
    expect(linked.scheduleId, scheduleId);
    expect(linked.name, createdSchedule.name);
    expect(custom.id, customId);
    expect(custom.serviceId, serviceId);
    expect(custom.scheduleId, isNull);
    expect((await client.listVehicles()).map((vehicle) => vehicle.id), contains(vehicleId));
    final listedSchedule = (await client.listSchedules(vehicleId)).single;
    expect(listedSchedule.id, scheduleId);
    final listedService = (await client.listServices(vehicleId, includeOperations: true)).single;
    expect(listedService.id, serviceId);
    expect(
      listedService.operations.map((operation) => operation.id),
      unorderedEquals([linkedId, customId]),
    );
    final operations = {
      for (final operation in await client.listOperations(serviceId)) operation.id: operation,
    };
    expect(operations.keys, unorderedEquals([linkedId, customId]));
    expect(operations[linkedId]?.scheduleId, scheduleId);
    expect(operations[customId]?.details, 'Front and rear');
  });

  test('reject malformed and non-v4 operation and relationship IDs', () async {
    for (final id in ['not-a-uuid', '12345678-abcd-7abc-8abc-1234567890ab']) {
      await expectLater(
        client.createOperation(service.id, id: id, name: 'Wash car'),
        throwsStatusCode(400),
      );
      await expectLater(client.createOperation(id, name: 'Wash car'), throwsStatusCode(400));
      await expectLater(client.createOperation(service.id, scheduleId: id), throwsStatusCode(400));
    }
    expect(await client.listOperations(service.id), isEmpty);
  });

  test('duplicate operation IDs return a generic conflict for accessible services', () async {
    final other = await harness.login();
    final otherVehicle = await other.createVehicle(
      name: 'Corolla',
      manufactureDate: CalendarDate(2020),
    );
    final otherService = await other.createService(
      otherVehicle.id,
      date: service.date,
      odometer: service.odometer,
    );
    final id = ResourceId.generate();
    await client.createOperation(service.id, id: id, scheduleId: schedule.id);

    for (final (writer, serviceId, scheduleId) in [
      (client, service.id, schedule.id),
      (other, otherService.id, null),
    ]) {
      await expectLater(
        writer.createOperation(serviceId, id: id, scheduleId: scheduleId, name: 'Wash car'),
        throwsA(
          isA<RequestFailure>()
              .having((failure) => failure.rawResponse.httpResponse.statusCode, 'status code', 409)
              .having((failure) => failure.rawResponse.document, 'document', isNull),
        ),
      );
    }
    await expectLater(
      other.createOperation(service.id, id: id, name: 'Wash car'),
      throwsStatusCode(404),
    );
    await expectLater(other.listOperations(service.id), throwsStatusCode(404));
    expect(await other.listOperations(otherService.id), isEmpty);
    final existing = (await client.listOperations(service.id)).single;
    expect(existing.id, id);
    expect(existing.name, schedule.name);
  });

  test('create and list a scheduled operation', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    expect(created.id, isNotEmpty);
    expect(created.serviceId, service.id);
    expect(created.scheduleId, schedule.id);
    expect(created.name, schedule.name);
    expect(created.details, isEmpty);
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.id, created.id);
    expect(listed.serviceId, service.id);
    expect(listed.scheduleId, schedule.id);
    expect(listed.name, schedule.name);
    expect(listed.details, isEmpty);
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
      date: CalendarDate(2024, 1, 16),
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
      date: CalendarDate(2024, 1, 16),
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

  test('editing can change schedule linkage without replacing operation text', () async {
    final created = await client.createOperation(service.id, name: 'Wash car');
    final linked = await client.updateOperation(created.id, scheduleId: schedule.id);
    expect(linked!.id, created.id);
    expect(linked.scheduleId, schedule.id);
    expect(linked.name, 'Wash car');
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
    expect(updated.name, schedule.name);
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
    expect(listed.details, isEmpty);
  });

  test('operation text stays independent of schedule edits', () async {
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
    expect(updated.name, schedule.name);
    expect(updated.details, isEmpty);
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
      client.createOperation(service.id, id: ResourceId.generate(), scheduleId: schedule.id),
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
      expect(listed.details, isEmpty);
      expect((await client.listSchedules(vehicle.id)).single.isArchived, isArchived);
    }
  });

  test('existing archived links can be retained or removed while editing', () async {
    final created = await client.createOperation(service.id, scheduleId: schedule.id);
    await archive(true);
    final retained = await client.updateOperation(created.id, scheduleId: schedule.id);
    expect(retained!.scheduleId, schedule.id);
    await client.updateService(service.id, date: CalendarDate(2024, 1, 16), odometer: 200);
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
          await client.updateService(service.id, date: CalendarDate.today(), odometer: 150);
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
            manufactureDate: CalendarDate(2020),
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
      final id = ResourceId.generate();
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
      date: CalendarDate(2024, 1, 16),
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
    final id = ResourceId.generate();
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
      final missingId = ResourceId.generate();
      await expectLater(
        existing == null
            ? client.createOperation(service.id, scheduleId: missingId)
            : client.updateOperation(existing.id, scheduleId: missingId),
        throwsStatusCode(400),
      );
    });
  }

  test('linked operation text is editable independently of its schedule', () async {
    final created = await client.createOperation(
      service.id,
      scheduleId: schedule.id,
      name: 'Performed oil work',
      details: 'Used 4 litres',
    );
    expect(created.name, 'Performed oil work');
    expect(created.details, 'Used 4 litres');
    final updated = await client.updateOperation(
      created.id,
      scheduleId: schedule.id,
      name: 'Oil and filter replaced',
      details: 'Checked for leaks',
    );
    expect(updated!.scheduleId, schedule.id);
    expect(updated.name, 'Oil and filter replaced');
    expect(updated.details, 'Checked for leaks');
    final listed = (await client.listOperations(service.id)).single;
    expect(listed.name, updated.name);
    expect(listed.details, updated.details);
    expect((await client.listSchedules(vehicle.id)).single.name, schedule.name);
    expect((await client.listSchedules(vehicle.id)).single.details, schedule.details);
  });

  for (final linked in [false, true]) {
    test('details-only edits preserve name and can clear details (linked: $linked)', () async {
      final created = await client.createOperation(
        service.id,
        scheduleId: linked ? schedule.id : null,
        name: 'Work performed',
        details: 'Initial notes',
      );
      final updated = await client.updateOperation(
        created.id,
        scheduleId: created.scheduleId,
        details: 'New notes',
      );
      expect(updated!.name, created.name);
      expect(updated.details, 'New notes');
      final cleared = await client.updateOperation(
        created.id,
        scheduleId: created.scheduleId,
        details: '',
      );
      expect(cleared!.name, created.name);
      expect(cleared.details, isEmpty);
    });
  }

  const invalidInputs = <({String label, String? name, bool isScheduled})>[
    (label: 'neither a schedule nor custom text', name: null, isScheduled: false),
    (label: 'an empty custom description', name: '', isScheduled: false),
    (label: 'a blank custom description', name: '   ', isScheduled: false),
    (label: 'an empty linked name', name: '', isScheduled: true),
    (label: 'a blank linked name', name: '   ', isScheduled: true),
  ];
  for (final input in invalidInputs) {
    for (final isEditing in [false, true]) {
      if (isEditing && input.name == null) continue;
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
