import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';

import 'harness.dart';

Future<void> main() async {
  late TestServer testServer;
  late TwApiClient client;

  Future<void> signIn(TwApiClient client, String code) async {
    await client.createSession();
    await testServer.googleCallback(code, state: testServer.googleOAuth.states.last);
  }

  Future<Resource> createVehicle() =>
      client.createVehicle(name: 'Civic', manufactureDate: DateTime.parse('2020-05-01'));

  Future<Resource> createService(String vehicleId) => client.createService(
    vehicleId,
    date: DateTime.parse('2026-10-01'),
    mileage: 45000,
    details: 'Replace oil and filter.',
  );

  group('Services', () {
    setUp(() async {
      testServer = await startTestServer();
      client = testServer.client;
    });

    tearDown(() async {
      await testServer.stop();
    });

    test('Unauthenticated users cannot create, list, or delete services', () async {
      await expectLater(() => createService('vehicle-id'), statusCode(401));
      await expectLater(() => client.listServices('vehicle-id'), statusCode(401));
      await expectLater(() => client.deleteService('service-id'), statusCode(401));
    });

    test('Create, list by vehicle, and delete a service', () async {
      String? location;
      client = TwApiClient(testServer.urlDesign, (request) async {
        final response = await testServer.clientHandler(request);
        location = response.headers['location']?.single;
        return response;
      });
      await signIn(client, 'test-code');
      final vehicle = await createVehicle();
      expect(await client.listServices(vehicle.id), isEmpty);

      final created = await client.createService(
        vehicle.id,
        date: DateTime.parse('2026-10-01'),
        mileage: 45000,
        details: 'Replace oil and filter.\nReset maintenance minder.',
      );
      expect(created.type, ResourceType.services);
      expect(created.id, isNotEmpty);
      expect(location, '${testConfig.baseUri}/services/${created.id}');
      expect(created.attributes, {
        'date': '2026-10-01',
        'mileage': 45000,
        'details': 'Replace oil and filter.\nReset maintenance minder.',
      });
      expect(created.relationships['vehicle']!.single.type, ResourceType.vehicles);
      expect(created.relationships['vehicle']!.single.id, vehicle.id);

      final listed = await client.listServices(vehicle.id);
      expect(listed.map((r) => r.id), [created.id]);
      expect(listed.single.attributes, created.attributes);
      expect(listed.single.relationships['vehicle']!.single.id, vehicle.id);

      await client.deleteService(created.id);
      expect(await client.listServices(vehicle.id), isEmpty);
      await expectLater(() => client.deleteService(created.id), statusCode(404));
    });

    test('Update an existing service and list the saved changes', () async {
      await signIn(client, 'test-code');
      final vehicle = await createVehicle();
      final created = await createService(vehicle.id);

      final updated = await client.updateService(
        vehicle.id,
        created.id,
        date: DateTime.parse('2026-10-15'),
        mileage: 46000,
        details: 'Replace oil, filter, and drain plug washer.',
      );

      expect(updated, isNotNull);
      expect(updated!.type, ResourceType.services);
      expect(updated.id, created.id);
      expect(updated.attributes, {
        'date': '2026-10-15',
        'mileage': 46000,
        'details': 'Replace oil, filter, and drain plug washer.',
      });
      expect(updated.relationships['vehicle']!.single.type, ResourceType.vehicles);
      expect(updated.relationships['vehicle']!.single.id, vehicle.id);

      final listed = await client.listServices(vehicle.id);
      expect(listed.map((r) => r.id), [created.id]);
      expect(listed.single.attributes, updated.attributes);
      expect(listed.single.relationships['vehicle']!.single.id, vehicle.id);
    });

    test('Date and mileage suffice; details defaults to empty text', () async {
      await signIn(client, 'test-code');
      final vehicle = await createVehicle();
      final created = await client.createService(
        vehicle.id,
        date: DateTime.parse('2026-10-01'),
        mileage: 0,
      );
      expect(created.attributes, {'date': '2026-10-01', 'mileage': 0, 'details': ''});
      expect((await client.listServices(vehicle.id)).single.attributes, created.attributes);
    });

    test('Related services contain only records for the requested vehicle', () async {
      await signIn(client, 'test-code');
      final first = await createVehicle();
      final second = await createVehicle();
      final firstService = await createService(first.id);
      final secondService = await createService(second.id);

      expect((await client.listServices(first.id)).map((r) => r.id), [firstService.id]);
      expect((await client.listServices(second.id)).map((r) => r.id), [secondService.id]);
    });

    test('Unknown vehicles and services return not found', () async {
      await signIn(client, 'test-code');
      const missingId = '00000000-0000-4000-8000-000000000000';
      await expectLater(() => client.listServices(missingId), statusCode(404));
      await expectLater(() => createService(missingId), statusCode(404));
      await expectLater(() => client.deleteService(missingId), statusCode(404));
    });

    test("Users cannot manage services for vehicles they don't own", () async {
      await signIn(client, 'test-code');
      final vehicle = await createVehicle();
      final service = await createService(vehicle.id);
      testServer.googleOAuth.email = 'other@example.com';
      testServer.googleOAuth.name = 'Other User';
      final otherClient = TwApiClient(testServer.urlDesign, testServer.clientHandler);
      await signIn(otherClient, 'other-code');

      await expectLater(() => otherClient.listServices(vehicle.id), statusCode(404));
      await expectLater(
        () => otherClient.createService(
          vehicle.id,
          date: DateTime.parse('2026-10-01'),
          mileage: 45000,
        ),
        statusCode(404),
      );
      await expectLater(() => otherClient.deleteService(service.id), statusCode(404));
      expect((await client.listServices(vehicle.id)).map((r) => r.id), [service.id]);
    });
  });
}
