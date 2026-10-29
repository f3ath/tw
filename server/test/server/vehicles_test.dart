import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:http_interop/extensions.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';

import 'harness.dart';

Future<void> main() async {
  late TestServer testServer;
  late TwApiClient client;

  Future<void> signIn(TwApiClient client, String code) async {
    await client.createSession();
    await testServer.googleCallback(code);
  }

  group('Vehicles', () {
    setUp(() async {
      testServer = await startTestServer();
      client = testServer.client;
    });

    tearDown(() async {
      await testServer.stop();
    });

    test('Unauthenticated vehicle operations are unauthorized', () async {
      await expectLater(client.listVehicles(), statusCode(401));
      await expectLater(
        client.createVehicle(name: 'Civic', manufactureDate: DateTime(2020, 5, 1)),
        statusCode(401),
      );
      await expectLater(client.fetchVehicle('vehicle-id'), statusCode(401));
      await expectLater(client.updateVehicle('vehicle-id', name: 'Accord'), statusCode(401));
      await expectLater(client.deleteVehicle('vehicle-id'), statusCode(401));
    });

    test('Vehicle Creation, Fetch, List, Update, Delete: Happy Path', () async {
      await signIn(client, 'test-code');

      final created = await client.createVehicle(
        name: 'Civic',
        manufactureDate: DateTime(2020, 5, 1),
      );

      expect(created.type, ResourceType.vehicles);
      expect(created.attributes, {
        'name': 'Civic',
        'manufacture_date': '2020-05-01',
        'distance_unit': 'mi',
      });

      final fetched = await client.fetchVehicle(created.id);
      expect(fetched.id, created.id);
      expect(fetched.attributes, {
        'name': 'Civic',
        'manufacture_date': '2020-05-01',
        'distance_unit': 'mi',
      });

      final listed = await client.listVehicles();
      expect(listed.map((r) => r.id), [created.id]);

      final updated = await client.updateVehicle(
        created.id,
        name: 'Accord',
        manufactureDate: DateTime(2021, 6, 2),
      );
      expect(updated!.id, created.id);
      expect(updated.attributes, {
        'name': 'Accord',
        'manufacture_date': '2021-06-02',
        'distance_unit': 'mi',
      });

      await client.deleteVehicle(created.id);

      await expectLater(client.fetchVehicle(created.id), statusCode(404));
      expect(await client.listVehicles(), isEmpty);
    });

    for (final unit in ['mi', 'km']) {
      test('Persists $unit through create, fetch, list, and update', () async {
        await signIn(client, 'test-code');
        final created = await client.createVehicle(
          name: 'Civic',
          manufactureDate: DateTime(2020, 5, 1),
          distanceUnit: unit,
        );
        expect(created.attributes['distance_unit'], unit);
        expect((await client.fetchVehicle(created.id)).attributes['distance_unit'], unit);
        expect((await client.listVehicles()).single.attributes['distance_unit'], unit);
        final updated = await client.updateVehicle(created.id, name: 'Accord');
        expect(updated!.attributes['distance_unit'], unit);
      });
    }

    TwApiClient withUnitAttribute(Object? unit, {bool omit = false}) =>
        TwApiClient(testServer.urlDesign, (request) async {
          if (request.method.toUpperCase() == 'POST' || request.method.toUpperCase() == 'PATCH') {
            final document = jsonDecode(await request.body.decode(utf8)) as Map<String, dynamic>;
            final attributes = document['data']['attributes'] as Map<String, dynamic>;
            if (omit) {
              attributes.remove('distance_unit');
            } else {
              attributes['distance_unit'] = unit;
            }
            request = Request(
              request.method,
              request.uri,
              Body.text(jsonEncode(document)),
              request.headers,
            );
          }
          return testServer.clientHandler(request);
        })..restoreState(client.saveState());

    test('Defaults omitted units to miles for existing clients', () async {
      await signIn(client, 'test-code');
      final created = await withUnitAttribute(
        null,
        omit: true,
      ).createVehicle(name: 'Civic', manufactureDate: DateTime(2020, 5, 1));
      expect(created.attributes['distance_unit'], 'mi');
    });

    for (final unit in ['miles', 'KM', '', null, 123]) {
      test('Rejects invalid distance unit $unit on creation', () async {
        await signIn(client, 'test-code');
        await expectLater(
          withUnitAttribute(unit)
              .createVehicle(name: 'Civic', manufactureDate: DateTime(2020, 5, 1)),
          statusCode(400),
        );
        expect(await client.listVehicles(), isEmpty);
      });
    }

    test('Rejects distance unit updates without applying other changes', () async {
      await signIn(client, 'test-code');
      final created = await client.createVehicle(
        name: 'Civic',
        manufactureDate: DateTime(2020, 5, 1),
        distanceUnit: 'km',
      );
      for (final unit in ['mi', 'km', null, 'invalid']) {
        await expectLater(
          withUnitAttribute(unit).updateVehicle(created.id, name: 'Accord'),
          statusCode(400),
        );
      }
      final fetched = await client.fetchVehicle(created.id);
      expect(fetched.attributes['distance_unit'], 'km');
      expect(fetched.attributes['name'], 'Civic');
    });

    test("Users can't access vehicles they don't own", () async {
      await signIn(client, 'test-code');
      final firstVehicle = await client.createVehicle(
        name: 'Civic',
        manufactureDate: DateTime(2020, 5, 1),
      );

      final secondClient = TwApiClient(testServer.urlDesign, testServer.clientHandler);
      testServer.googleOAuth.email = 'other@example.com';
      testServer.googleOAuth.name = 'Other User';
      await signIn(secondClient, 'other-code');

      await expectLater(secondClient.fetchVehicle(firstVehicle.id), statusCode(404));
      await expectLater(
        secondClient.updateVehicle(
          firstVehicle.id,
          name: 'Accord',
          manufactureDate: DateTime(2021, 6, 2),
        ),
        statusCode(404),
      );
      await expectLater(secondClient.deleteVehicle(firstVehicle.id), statusCode(404));
      expect(await secondClient.listVehicles(), isEmpty);

      final fetchedByOwner = await client.fetchVehicle(firstVehicle.id);
      expect(fetchedByOwner.attributes, {
        'name': 'Civic',
        'manufacture_date': '2020-05-01',
        'distance_unit': 'mi',
      });
    });
  });
}
