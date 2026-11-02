import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'harness.dart';

void main() {
  late TestHarness harness;
  final manufactured = DateTime(2020, 5, 1);

  setUp(() async {
    harness = TestHarness();
    await harness.startServer();
  });

  tearDown(() async {
    await harness.stopServer();
  });

  test('a new account has an empty garage', () async {
    final client = await harness.login();
    expect(await client.listVehicles(), isEmpty);
  });

  for (final unit in ['mi', 'km']) {
    test('create, fetch, and list a vehicle measured in $unit', () async {
      final client = await harness.login();
      final created = await client.createVehicle(
        name: 'Civic',
        manufactureDate: manufactured,
        distanceUnit: unit,
      );
      expect(created.id, isNotEmpty);
      expect(created.name, 'Civic');
      expect(created.manufactureDate, manufactured);
      expect(created.distanceUnit, unit);

      final fetched = await client.fetchVehicle(created.id);
      expect(fetched.id, created.id);
      expect(fetched.name, created.name);
      expect(fetched.manufactureDate, created.manufactureDate);
      expect(fetched.distanceUnit, unit);

      final listed = (await client.listVehicles()).single;
      expect(listed.id, created.id);
      expect(listed.name, created.name);
      expect(listed.manufactureDate, created.manufactureDate);
      expect(listed.distanceUnit, unit);
    });
  }

  test('save edited vehicle fields while preserving its ID and distance unit', () async {
    final client = await harness.login();
    final created = await client.createVehicle(
      name: 'Civic',
      manufactureDate: manufactured,
      distanceUnit: 'km',
    );
    final editedDate = DateTime(2019, 4, 2);
    final updated = await client.updateVehicle(
      created.id,
      name: 'My Civic',
      manufactureDate: editedDate,
    );
    expect(updated, isNotNull);
    expect(updated!.id, created.id);
    expect(updated.name, 'My Civic');
    expect(updated.manufactureDate, editedDate);
    expect(updated.distanceUnit, 'km');

    final fetched = await client.fetchVehicle(created.id);
    expect(fetched.name, updated.name);
    expect(fetched.manufactureDate, updated.manufactureDate);
    expect(fetched.distanceUnit, 'km');
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
    await first.deleteSession();

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
      other.updateVehicle(created.id, name: 'Changed', manufactureDate: DateTime(2018)),
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
    final id = const Uuid().v4();
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
      client.createVehicle(name: 'Civic', manufactureDate: DateTime(9999)),
      throwsStatusCode(400),
    );
    expect(await client.listVehicles(), isEmpty);
  });

  test('reject a future manufacture date on editing', () async {
    final client = await harness.login();
    final vehicle = await client.createVehicle(name: 'Civic', manufactureDate: manufactured);
    await expectLater(
      client.updateVehicle(vehicle.id, name: 'Civic', manufactureDate: DateTime(9999)),
      throwsStatusCode(400),
    );
    expect((await client.fetchVehicle(vehicle.id)).manufactureDate, manufactured);
  });

  test('reject an unsupported distance unit', () async {
    final client = await harness.login();
    await expectLater(
      client.createVehicle(name: 'Civic', manufactureDate: manufactured, distanceUnit: 'invalid'),
      throwsStatusCode(400),
    );
    expect(await client.listVehicles(), isEmpty);
  });
}
