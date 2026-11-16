import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  final harness = TestHarness();
  late TwApiClient client;
  late Vehicle vehicle;
  final manufactured = DateTime(2020, 1, 1);
  final serviceDate = DateTime(2024, 1, 15);

  setUp(() async {
    await harness.startServer();
    client = await harness.login();
    vehicle = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
  });

  tearDown(() async {
    await harness.stopServer();
  });

  Future<Service> createService() =>
      client.createService(vehicle.id, date: serviceDate, odometer: 150);

  test('a new vehicle has an empty service history', () async {
    expect(await client.listServices(vehicle.id), isEmpty);
  });

  for (final unit in DistanceUnit.values) {
    test('create and list an odometer-only entry in ${unit.name}', () async {
      final target = await client.createVehicle(
        name: 'Corolla',
        manufactureDate: manufactured,
        distanceUnit: unit,
      );
      final created = await client.createService(target.id, date: serviceDate, odometer: 150);
      expect(created.id, isNotEmpty);
      expect(created.vehicleId, target.id);
      expect(created.date, serviceDate);
      expect(created.odometer, 150);
      final listed = (await client.listServices(target.id)).single;
      expect(listed.id, created.id);
      expect(listed.vehicleId, target.id);
      expect(listed.date, serviceDate);
      expect(listed.odometer, 150);
      expect(await client.listServices(vehicle.id), isEmpty);
    });
  }

  test('zero is a valid odometer reading on the manufacture date', () async {
    final created = await client.createService(vehicle.id, date: manufactured, odometer: 0);
    expect(created.odometer, 0);
    expect(created.date, manufactured);
    expect((await client.listServices(vehicle.id)).single.odometer, 0);
  });

  test('today is a valid service date', () async {
    final now = systemClock();
    final today = DateTime(now.year, now.month, now.day);
    final created = await client.createService(vehicle.id, date: today, odometer: 150);
    expect(created.date, today);
  });

  for (final isEditing in [false, true]) {
    test('allow service dates seven days ahead on ${isEditing ? 'editing' : 'creation'}', () async {
      final now = systemClock();
      final date = DateTime(now.year, now.month, now.day + 7);
      final existing = isEditing ? await createService() : null;
      final saved = existing == null
          ? await client.createService(vehicle.id, date: date, odometer: 150)
          : await client.updateService(existing.id, date: date, odometer: 150);
      expect(saved!.date, date);
      expect((await client.listServices(vehicle.id)).single.date, date);
    });

    test(
      'reject service dates eight days ahead on ${isEditing ? 'editing' : 'creation'}',
      () async {
        final now = systemClock();
        final date = DateTime(now.year, now.month, now.day + 8);
        final existing = isEditing ? await createService() : null;
        await expectLater(
          existing == null
              ? client.createService(vehicle.id, date: date, odometer: 150)
              : client.updateService(existing.id, date: date, odometer: 150),
          throwsStatusCode(400),
        );
        final services = await client.listServices(vehicle.id);
        expect(services, hasLength(isEditing ? 1 : 0));
        if (isEditing) expect(services.single.date, serviceDate);
      },
    );
  }

  test('save edited date, odometer, and details on the same service', () async {
    final created = await createService();
    final date = DateTime(2024, 1, 16);
    final updated = await client.updateService(
      created.id,
      date: date,
      odometer: 200,
      details: 'Updated notes',
    );
    expect(updated, isNotNull);
    expect(updated!.id, created.id);
    expect(updated.vehicleId, vehicle.id);
    expect(updated.date, date);
    expect(updated.odometer, 200);
    expect(updated.details, 'Updated notes');
    final listed = (await client.listServices(vehicle.id)).single;
    expect(listed.id, created.id);
    expect(listed.date, date);
    expect(listed.odometer, 200);
    expect(listed.details, 'Updated notes');
  });

  test(
    'delete a service without removing other entries; deleting the last leaves empty history',
    () async {
      final first = await createService();
      final second = await client.createService(
        vehicle.id,
        date: DateTime(2024, 1, 16),
        odometer: 200,
      );
      await client.deleteService(first.id);
      expect((await client.listServices(vehicle.id)).single.id, second.id);
      await client.deleteService(second.id);
      expect(await client.listServices(vehicle.id), isEmpty);
    },
  );

  test('services persist across sessions for the same account', () async {
    final created = await createService();
    final email = (await client.fetchCurrentUser())!.email;
    await client.deleteCurrentSession();
    final restored = await harness.login(email: email);
    final listed = (await restored.listServices(vehicle.id)).single;
    expect(listed.id, created.id);
    expect(listed.date, serviceDate);
    expect(listed.odometer, 150);
  });

  for (final isPending in [false, true]) {
    test('service CRUD requires ${isPending ? 'completed sign-in' : 'authentication'}', () async {
      final created = await createService();
      final unauthorized = harness.newClient();
      if (isPending) await unauthorized.createSession();
      await expectLater(unauthorized.listServices(vehicle.id), throwsStatusCode(401));
      await expectLater(
        unauthorized.createService(vehicle.id, date: serviceDate, odometer: 150),
        throwsStatusCode(401),
      );
      await expectLater(
        unauthorized.updateService(created.id, date: serviceDate, odometer: 150),
        throwsStatusCode(401),
      );
      await expectLater(unauthorized.deleteService(created.id), throwsStatusCode(401));
      expect((await client.listServices(vehicle.id)).single.id, created.id);
    });
  }

  test("users cannot list, create, edit, or delete another user's service", () async {
    final created = await createService();
    final other = await harness.login();
    await expectLater(other.listServices(vehicle.id), throwsStatusCode(404));
    await expectLater(
      other.createService(vehicle.id, date: serviceDate, odometer: 150),
      throwsStatusCode(404),
    );
    await expectLater(
      other.updateService(created.id, date: serviceDate, odometer: 200),
      throwsStatusCode(404),
    );
    await expectLater(other.deleteService(created.id), throwsStatusCode(404));
    final unchanged = (await client.listServices(vehicle.id)).single;
    expect(unchanged.id, created.id);
    expect(unchanged.odometer, 150);
  });

  test('missing vehicles and services return not found', () async {
    final missing = const Uuid().v4();
    await expectLater(client.listServices(missing), throwsStatusCode(404));
    await expectLater(
      client.createService(missing, date: serviceDate, odometer: 150),
      throwsStatusCode(404),
    );
    await expectLater(
      client.updateService(missing, date: serviceDate, odometer: 150),
      throwsStatusCode(404),
    );
    await expectLater(client.deleteService(missing), throwsStatusCode(404));
  });

  test('editing a service preserves its original vehicle', () async {
    final created = await createService();
    final otherVehicle = await client.createVehicle(name: 'Corolla', manufactureDate: manufactured);
    final updated = await client.updateService(created.id, date: serviceDate, odometer: 200);
    expect(updated!.vehicleId, vehicle.id);
    final listed = (await client.listServices(vehicle.id)).single;
    expect(listed.id, created.id);
    expect(listed.vehicleId, vehicle.id);
    expect(listed.odometer, 200);
    expect(await client.listServices(otherVehicle.id), isEmpty);
  });

  for (final isEditing in [false, true]) {
    test('reject a negative odometer on ${isEditing ? 'editing' : 'creation'}', () async {
      final existing = isEditing ? await createService() : null;
      await expectLater(
        existing == null
            ? client.createService(vehicle.id, date: serviceDate, odometer: -1)
            : client.updateService(existing.id, date: serviceDate, odometer: -1),
        throwsStatusCode(400),
      );
      final services = await client.listServices(vehicle.id);
      expect(services, hasLength(isEditing ? 1 : 0));
      if (isEditing) expect(services.single.odometer, 150);
    });
  }
  for (final invalid in [
    (label: 'before manufacture', date: DateTime(2019, 12, 31)),
    (label: 'more than seven days in the future', date: DateTime(9999)),
  ]) {
    for (final isEditing in [false, true]) {
      test('reject a date ${invalid.label} on ${isEditing ? 'editing' : 'creation'}', () async {
        final existing = isEditing ? await createService() : null;
        await expectLater(
          existing == null
              ? client.createService(vehicle.id, date: invalid.date, odometer: 150)
              : client.updateService(existing.id, date: invalid.date, odometer: 150),
          throwsStatusCode(400),
        );
        final services = await client.listServices(vehicle.id);
        expect(services, hasLength(isEditing ? 1 : 0));
        if (isEditing) expect(services.single.date, serviceDate);
      });
    }
  }

  for (final odometer in [99, 201]) {
    for (final isEditing in [false, true]) {
      test(
        'reject odometer $odometer outside chronological neighbors on ${isEditing ? 'editing' : 'creation'}',
        () async {
          await client.createService(vehicle.id, date: DateTime(2024, 1, 10), odometer: 100);
          await client.createService(vehicle.id, date: DateTime(2024, 1, 20), odometer: 200);
          final existing = isEditing ? await createService() : null;
          await expectLater(
            existing == null
                ? client.createService(vehicle.id, date: serviceDate, odometer: odometer)
                : client.updateService(existing.id, date: serviceDate, odometer: odometer),
            throwsStatusCode(400),
          );
          final services = await client.listServices(vehicle.id);
          expect(services, hasLength(isEditing ? 3 : 2));
          if (isEditing) {
            expect(services.singleWhere((service) => service.id == existing!.id).odometer, 150);
          }
        },
      );
    }
  }

  test('editing a date must also respect chronological odometer bounds', () async {
    await client.createService(vehicle.id, date: DateTime(2024, 1, 10), odometer: 100);
    final existing = await createService();
    await client.createService(vehicle.id, date: DateTime(2024, 1, 20), odometer: 200);
    for (final date in [DateTime(2024, 1, 9), DateTime(2024, 1, 21)]) {
      await expectLater(
        client.updateService(existing.id, date: date, odometer: 150),
        throwsStatusCode(400),
      );
      expect(
        (await client.listServices(vehicle.id))
            .singleWhere((service) => service.id == existing.id)
            .date,
        serviceDate,
      );
    }
  });

  test('equal odometer readings across different dates are allowed', () async {
    await client.createService(vehicle.id, date: DateTime(2024, 1, 10), odometer: 150);
    final middle = await createService();
    await client.createService(vehicle.id, date: DateTime(2024, 1, 20), odometer: 150);
    expect(
      (await client.listServices(vehicle.id)).map((service) => service.odometer),
      everyElement(150),
    );
    final updated = await client.updateService(
      middle.id,
      date: DateTime(2024, 1, 16),
      odometer: 150,
    );
    expect(updated!.date, DateTime(2024, 1, 16));
  });

  test(
    'same-date entries may have different readings; edits exclude their own previous reading',
    () async {
      final first = await createService();
      await client.createService(vehicle.id, date: serviceDate, odometer: 100);
      final updated = await client.updateService(first.id, date: serviceDate, odometer: 200);
      expect(updated!.id, first.id);
      expect(updated.odometer, 200);
      expect(
        (await client.listServices(vehicle.id)).map((service) => service.odometer),
        unorderedEquals([100, 200]),
      );
    },
  );

  for (final edit in [
    (label: 'earlier date and higher reading', date: DateTime(2024, 1, 14), odometer: 200),
    (label: 'later date and lower reading', date: DateTime(2024, 1, 16), odometer: 100),
  ]) {
    test('editing to ${edit.label} excludes the old version from bounds', () async {
      final created = await createService();
      final updated = await client.updateService(
        created.id,
        date: edit.date,
        odometer: edit.odometer,
      );
      expect(updated!.id, created.id);
      final listed = (await client.listServices(vehicle.id)).single;
      expect(listed.date, edit.date);
      expect(listed.odometer, edit.odometer);
    });
  }

  test('manufacture-date edits cannot invalidate an existing service date', () async {
    await createService();
    await expectLater(
      client.updateVehicle(vehicle.id, name: vehicle.name, manufactureDate: DateTime(2024, 1, 16)),
      throwsStatusCode(400),
    );
    expect((await client.fetchVehicle(vehicle.id)).manufactureDate, manufactured);
  });

  test('concurrent service writes cannot create decreasing odometer history', () async {
    final otherHarness = TestHarness();
    addTearDown(otherHarness.stopServer);
    await otherHarness.startServer();
    final email = (await client.fetchCurrentUser())!.email;
    final other = await otherHarness.login(email: email);
    final results = await Future.wait([
      client
          .createService(vehicle.id, date: DateTime(2024, 1, 10), odometer: 200)
          .then<Object>((value) => value, onError: (Object error) => error),
      other
          .createService(vehicle.id, date: DateTime(2024, 1, 20), odometer: 100)
          .then<Object>((value) => value, onError: (Object error) => error),
    ]);
    expect(results.whereType<Service>(), hasLength(1));
    final failure = results.whereType<RequestFailure>().single;
    expect(failure.rawResponse.httpResponse.statusCode, 400);
    expect(await client.listServices(vehicle.id), hasLength(1));
  });

  test('concurrent manufacture-date edits and service creation keep dates consistent', () async {
    final otherHarness = TestHarness();
    addTearDown(otherHarness.stopServer);
    await otherHarness.startServer();
    final email = (await client.fetchCurrentUser())!.email;
    final other = await otherHarness.login(email: email);
    final results = await Future.wait([
      createService().then<Object>((value) => value, onError: (Object error) => error),
      other
          .updateVehicle(vehicle.id, manufactureDate: DateTime(2024, 1, 16))
          .then<Object>((value) => value!, onError: (Object error) => error),
    ]);
    final failure = results.whereType<RequestFailure>().single;
    expect(failure.rawResponse.httpResponse.statusCode, 400);
    expect(results.where((value) => value is Service || value is Vehicle), hasLength(1));
    final current = await client.fetchVehicle(vehicle.id);
    for (final service in await client.listServices(vehicle.id)) {
      expect(service.date.isBefore(current.manufactureDate), isFalse);
    }
  });
}
