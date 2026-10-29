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
      expect(created.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});

      final fetched = await client.fetchVehicle(created.id);
      expect(fetched.id, created.id);
      expect(fetched.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});

      final listed = await client.listVehicles();
      expect(listed.map((r) => r.id), [created.id]);

      final updated = await client.updateVehicle(
        created.id,
        name: 'Accord',
        manufactureDate: DateTime(2021, 6, 2),
      );
      expect(updated!.id, created.id);
      expect(updated.attributes, {'name': 'Accord', 'manufacture_date': '2021-06-02'});

      await client.deleteVehicle(created.id);

      await expectLater(client.fetchVehicle(created.id), statusCode(404));
      expect(await client.listVehicles(), isEmpty);
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
      expect(fetchedByOwner.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});
    });
  });
}
