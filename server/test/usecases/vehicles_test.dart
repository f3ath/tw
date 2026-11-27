import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:shared/resource_id.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  final harness = TestHarness();
  final manufactured = CalendarDate(2020, 5, 1);

  setUp(() async {
    await harness.startServer();
  });

  tearDown(() async {
    await harness.stopServer();
  });

  test('mileage units can be changed in both directions and omitted on updates', () async {
    final client = await harness.login();
    final vehicle = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
    for (final unit in [MileageUnit.km, MileageUnit.mi]) {
      final updated = await client.updateVehicle(vehicle.id, mileageUnit: unit);
      expect(updated!.mileageUnit, unit);
      expect((await client.fetchVehicle(vehicle.id)).mileageUnit, unit);
      await client.updateVehicle(vehicle.id, name: 'Renamed');
      expect((await client.fetchVehicle(vehicle.id)).mileageUnit, unit);
    }
  });

  test('a new account has an empty garage', () async {
    final client = await harness.login();
    expect(await client.listVehicles(), isEmpty);
  });

  test('listing vehicles returns the odometer reading when available', () async {
    final client = await harness.login();
    final serviced = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
    final unserviced = await client.createVehicle(name: 'Corolla', manufactureDate: manufactured);
    final date = CalendarDate(2021);
    await client.createService(serviced.id, date: date, odometer: 100);

    final listed = await client.listVehicles();
    final reading = listed.singleWhere((vehicle) => vehicle.id == serviced.id).odometer!;
    expect(reading.date, date);
    expect(reading.value, 100);
    expect(listed.singleWhere((vehicle) => vehicle.id == unserviced.id).odometer, isNull);
  });

  for (final unit in MileageUnit.values) {
    test('create, fetch, and list a vehicle measured in ${unit.name}', () async {
      final client = await harness.login();
      final created = await client.createVehicle(
        name: 'Civic',
        manufactureDate: manufactured,
        mileageUnit: unit,
      );
      expect(ResourceId.isValid(created.id), isTrue);
      expect(created.name, 'Civic');
      expect(created.manufactureDate, manufactured);
      expect(created.mileageUnit, unit);

      final fetched = await client.fetchVehicle(created.id);
      expect(fetched.id, created.id);
      expect(fetched.name, created.name);
      expect(fetched.manufactureDate, created.manufactureDate);
      expect(fetched.mileageUnit, unit);

      final listed = (await client.listVehicles()).single;
      expect(listed.id, created.id);
      expect(listed.name, created.name);
      expect(listed.manufactureDate, created.manufactureDate);
      expect(listed.mileageUnit, unit);
    });
  }

  test('persist an explicit vehicle ID', () async {
    final client = await harness.login();
    final id = ResourceId.generate();
    final created = await client.createVehicle(
      id: id,
      name: 'Civic',
      manufactureDate: manufactured,
    );

    expect(created.id, id);
    expect((await client.fetchVehicle(id)).name, 'Civic');
    expect((await client.listVehicles()).single.id, id);
  });

  test('persist an uppercase vehicle ID in the database output format', () async {
    final client = await harness.login();
    final id = 'a${ResourceId.generate().substring(1)}';
    final created = await client.createVehicle(
      id: id.toUpperCase(),
      name: 'Civic',
      manufactureDate: manufactured,
    );

    expect(created.id, id);
    expect((await client.fetchVehicle(id)).name, 'Civic');
  });

  test('reject vehicle IDs outside the hyphenated UUID v4 format', () async {
    final client = await harness.login();
    const validId = '12345678-abcd-4abc-8abc-1234567890ab';
    for (final id in [
      '',
      'not-a-uuid',
      validId.replaceAll('-', ''),
      '12345678-abcd-7abc-8abc-1234567890ab',
      '12345678-abcd-4abc-7abc-1234567890ab',
      '$validId\n',
    ]) {
      await expectLater(
        client.createVehicle(id: id, name: 'Civic', manufactureDate: manufactured),
        throwsStatusCode(400),
        reason: 'Rejected ID: ${id.codeUnits}',
      );
    }
    expect(await client.listVehicles(), isEmpty);
  });

  test('return a generic conflict for duplicate IDs within and across tenants', () async {
    final owner = await harness.login();
    final other = await harness.login();
    final id = 'a${ResourceId.generate().substring(1)}';
    await owner.createVehicle(id: id, name: 'Civic', manufactureDate: manufactured);

    for (final client in [owner, other]) {
      await expectLater(
        client.createVehicle(id: id.toUpperCase(), name: 'Corolla', manufactureDate: manufactured),
        throwsA(
          isA<RequestFailure>()
              .having((failure) => failure.rawResponse.httpResponse.statusCode, 'status code', 409)
              .having((failure) => failure.rawResponse.document, 'document', isNull),
        ),
      );
    }
    await expectLater(other.fetchVehicle(id), throwsStatusCode(404));
    expect(await other.listVehicles(), isEmpty);
    expect((await owner.listVehicles()).single.id, id);
    expect((await owner.fetchVehicle(id)).name, 'Civic');
  });

  test('concurrent vehicle creates with the same ID have one winner', () async {
    final client = await harness.login();
    final otherHarness = TestHarness();
    addTearDown(otherHarness.stopServer);
    await otherHarness.startServer();
    final other = await otherHarness.login(email: (await client.fetchCurrentUser())!.email);
    final id = ResourceId.generate();

    final results = await Future.wait([
      for (final writer in [client, other])
        writer
            .createVehicle(id: id, name: 'Civic', manufactureDate: manufactured)
            .then<Object>((vehicle) => vehicle, onError: (Object error) => error),
    ]);

    expect(results.whereType<Vehicle>().single.id, id);
    expect(results.whereType<RequestFailure>().single.rawResponse.httpResponse.statusCode, 409);
    expect((await client.listVehicles()).single.id, id);
  });

  test('save edited vehicle fields while preserving its ID', () async {
    final client = await harness.login();
    final created = await client.createVehicle(
      name: 'Civic',
      manufactureDate: manufactured,
      mileageUnit: MileageUnit.km,
    );
    final editedDate = CalendarDate(2019, 4, 2);
    final updated = await client.updateVehicle(
      created.id,
      name: 'My Civic',
      manufactureDate: editedDate,
      mileageUnit: MileageUnit.mi,
    );
    expect(updated, isNotNull);
    expect(updated!.id, created.id);
    expect(updated.name, 'My Civic');
    expect(updated.manufactureDate, editedDate);
    expect(updated.mileageUnit, MileageUnit.mi);

    final fetched = await client.fetchVehicle(created.id);
    expect(fetched.name, updated.name);
    expect(fetched.manufactureDate, updated.manufactureDate);
    expect(fetched.mileageUnit, MileageUnit.mi);
    expect((await client.listVehicles()).single.name, updated.name);
  });

  test('delete a vehicle without removing other vehicles', () async {
    final client = await harness.login();
    final first = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
    final second = await client.createVehicle(name: 'Corolla', manufactureDate: manufactured);

    await client.deleteVehicle(first.id);

    await expectLater(client.fetchVehicle(first.id), throwsStatusCode(404));
    expect((await client.listVehicles()).single.id, second.id);
    expect((await client.fetchVehicle(second.id)).name, 'Corolla');
  });

  test('vehicles persist across sessions for the same account', () async {
    final first = await harness.login();
    final email = (await first.fetchCurrentUser())!.email;
    final created = await first.createVehicle(name: 'Civic', manufactureDate: manufactured);
    await first.deleteCurrentSession();

    final second = await harness.login(email: email);
    expect((await second.listVehicles()).single.id, created.id);
    expect((await second.fetchVehicle(created.id)).name, 'Civic');
  });

  test("users cannot list, fetch, edit, or delete another user's vehicle", () async {
    final owner = await harness.login();
    final created = await owner.createVehicle(name: 'Civic', manufactureDate: manufactured);
    final other = await harness.login();

    expect(await other.listVehicles(), isEmpty);
    await expectLater(other.fetchVehicle(created.id), throwsStatusCode(404));
    await expectLater(
      other.updateVehicle(created.id, name: 'Changed', manufactureDate: CalendarDate(2018)),
      throwsStatusCode(404),
    );
    await expectLater(other.deleteVehicle(created.id), throwsStatusCode(404));
    final unchanged = await owner.fetchVehicle(created.id);
    expect(unchanged.name, created.name);
    expect(unchanged.manufactureDate, created.manufactureDate);
  });

  for (final pending in [false, true]) {
    test('vehicle CRUD requires ${pending ? 'completed sign-in' : 'authentication'}', () async {
      final owner = await harness.login();
      final vehicle = await owner.createVehicle(name: 'Civic', manufactureDate: manufactured);
      final client = harness.newClient();
      if (pending) await client.createSession();

      await expectLater(client.listVehicles(), throwsStatusCode(401));
      await expectLater(client.fetchVehicle(vehicle.id), throwsStatusCode(401));
      await expectLater(
        client.createVehicle(name: 'Corolla', manufactureDate: manufactured),
        throwsStatusCode(401),
      );
      await expectLater(
        client.updateVehicle(vehicle.id, name: 'Changed', manufactureDate: manufactured),
        throwsStatusCode(401),
      );
      await expectLater(client.deleteVehicle(vehicle.id), throwsStatusCode(401));
      expect((await owner.listVehicles()).single.id, vehicle.id);
      expect((await owner.fetchVehicle(vehicle.id)).name, 'Civic');
    });
  }

  test('missing vehicles return not found', () async {
    final client = await harness.login();
    final id = ResourceId.generate();
    await expectLater(client.fetchVehicle(id), throwsStatusCode(404));
    await expectLater(
      client.updateVehicle(id, name: 'Civic', manufactureDate: manufactured),
      throwsStatusCode(404),
    );
    await expectLater(client.deleteVehicle(id), throwsStatusCode(404));
  });

  for (final name in ['', '   ']) {
    test('reject a blank name on creation (${name.length} characters)', () async {
      final client = await harness.login();
      await expectLater(
        client.createVehicle(name: name, manufactureDate: manufactured),
        throwsStatusCode(400),
      );
      expect(await client.listVehicles(), isEmpty);
    });

    test('reject a blank name on editing (${name.length} characters)', () async {
      final client = await harness.login();
      final vehicle = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
      await expectLater(
        client.updateVehicle(vehicle.id, name: name, manufactureDate: manufactured),
        throwsStatusCode(400),
      );
      expect((await client.fetchVehicle(vehicle.id)).name, 'Civic');
    });
  }

  test('reject a future manufacture date on creation', () async {
    final client = await harness.login();
    await expectLater(
      client.createVehicle(name: 'Civic', manufactureDate: CalendarDate(9999)),
      throwsStatusCode(400),
    );
    expect(await client.listVehicles(), isEmpty);
  });

  test('reject a future manufacture date on editing', () async {
    final client = await harness.login();
    final vehicle = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
    await expectLater(
      client.updateVehicle(vehicle.id, name: 'Civic', manufactureDate: CalendarDate(9999)),
      throwsStatusCode(400),
    );
    expect((await client.fetchVehicle(vehicle.id)).manufactureDate, manufactured);
  });
}
