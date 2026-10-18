import 'package:json_api/client.dart' hide Request;
import 'package:test/test.dart';
import 'package:tw_shared/api.dart';

import 'harness.dart';

Future<void> main() async {
  late TestApplication app;
  late TwApiClient client;

  Future<void> signIn(TwApiClient client, String code) async {
    await client.createSession();
    await app.googleCallback(code, state: app.googleOAuth.states.last);
  }

  Matcher statusCode(int expected) => throwsA(
    isA<RequestFailure>().having(
      (r) => r.rawResponse.httpResponse.statusCode,
      'Status Code',
      equals(expected),
    ),
  );

  group('Schedules', () {
    setUp(() async {
      app = await startTestApplication();
      client = app.client;
    });

    tearDown(() async {
      await app.stop();
    });

    test('No Auth Header: Unauthorized', () async {
      expect(() => client.listSchedules('vehicle-id'), statusCode(401));
      expect(
        () => client.createSchedule(
          'vehicle-id',
          name: 'Oil change',
          intervalMiles: 5000,
          intervalMonths: 6,
          details: 'Replace oil and filter.',
        ),
        statusCode(401),
      );
      expect(
        () => client.updateSchedule('vehicle-id', 'schedule-id', name: 'Oil and filter change'),
        statusCode(401),
      );
      expect(() => client.deleteSchedule('schedule-id'), statusCode(401));
    });

    test('Create, List, Update, Delete: Happy Path', () async {
      String? location;
      client = TwApiClient(app.urlDesign, (request) async {
        final response = await app.clientHandler(request);
        location = response.headers['location']?.single;
        return response;
      });
      await signIn(client, 'test-code');
      final vehicle = await client.createVehicle(
        name: 'Civic',
        manufactureDate: DateTime.parse('2020-05-01'),
      );

      final created = await client.createSchedule(
        vehicle.id,
        name: 'Oil change',
        intervalMiles: 5000,
        intervalMonths: 6,
        details: '''
Use 0W-20 synthetic oil.

- Replace drain plug washer
- Reset maintenance minder''',
      );

      expect(created.type, ResourceType.schedules);
      expect(location, '${testConfig.baseUri}/schedules/${created.id}');
      expect(created.attributes, {
        'name': 'Oil change',
        'interval_miles': 5000,
        'interval_months': 6,
        'details': '''
Use 0W-20 synthetic oil.

- Replace drain plug washer
- Reset maintenance minder''',
      });
      expect(created.relationships['vehicle']!.single.type, ResourceType.vehicles);
      expect(created.relationships['vehicle']!.single.id, vehicle.id);

      final listed = await client.listSchedules(vehicle.id);
      expect(listed.map((r) => r.id), [created.id]);
      expect(listed.single.relationships['vehicle']!.single.id, vehicle.id);

      final updated = await client.updateSchedule(
        vehicle.id,
        created.id,
        name: 'Engine oil change',
        intervalMiles: 7500,
        intervalMonths: 12,
        details: 'Replace oil, filter, and drain plug washer.',
      );
      expect(updated!.id, created.id);
      expect(updated.attributes, {
        'name': 'Engine oil change',
        'interval_miles': 7500,
        'interval_months': 12,
        'details': 'Replace oil, filter, and drain plug washer.',
      });
      expect(updated.relationships['vehicle']!.single.id, vehicle.id);

      await client.deleteSchedule(created.id);

      expect(await client.listSchedules(vehicle.id), isEmpty);
    });

    test("Users can't manage schedules for vehicles they don't own", () async {
      await signIn(client, 'test-code');
      final vehicle = await client.createVehicle(
        name: 'Civic',
        manufactureDate: DateTime.parse('2020-05-01'),
      );
      final schedule = await client.createSchedule(
        vehicle.id,
        name: 'Oil change',
        intervalMiles: 5000,
        intervalMonths: 6,
        details: 'Replace oil and filter.',
      );

      final secondClient = TwApiClient(app.urlDesign, app.clientHandler);
      app.googleOAuth.email = 'other@example.com';
      app.googleOAuth.name = 'Other User';
      await signIn(secondClient, 'other-code');

      expect(() => secondClient.listSchedules(vehicle.id), statusCode(404));
      expect(
        () => secondClient.createSchedule(
          vehicle.id,
          name: 'Brake fluid',
          intervalMiles: 30000,
          intervalMonths: 36,
          details: 'Flush brake fluid.',
        ),
        statusCode(404),
      );
      expect(
        () => secondClient.updateSchedule(vehicle.id, schedule.id, name: 'Engine oil change'),
        statusCode(404),
      );
      expect(() => secondClient.deleteSchedule(schedule.id), statusCode(404));

      expect((await client.listSchedules(vehicle.id)).map((r) => r.id), [schedule.id]);
    });
  });
}
