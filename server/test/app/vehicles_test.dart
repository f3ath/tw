import 'package:json_api/client.dart' hide Request;
import 'package:json_api/document.dart';
import 'package:test/test.dart';
import 'package:shared/api.dart';

import 'harness.dart';

Future<void> main() async {
  late TestApplication app;
  late TwApiClient client;
  late RoutingClient jsonApi;

  Future<Resource> signIn(TwApiClient client, String code) async {
    final session = await client.createSession();
    await app.googleCallback(code, state: app.googleOAuth.states.last);
    return session!;
  }

  Map<String, List<String>> authHeaders(Resource session) => {
    'Authorization': ['Bearer ${session.attributes['key'] as String}'],
  };

  group('Vehicles', () {
    setUp(() async {
      app = await startTestApplication();
      client = app.client;
      jsonApi = RoutingClient(app.urlDesign.uri, Client(app.clientHandler));
    });

    tearDown(() async {
      await app.stop();
    });

    test('No Auth Header: Unauthorized', () async {
      expect(() => jsonApi.fetchCollection(ResourceType.vehicles), statusCode(401));
      expect(
        () => jsonApi.createNew(
          ResourceType.vehicles,
          attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        ),
        statusCode(401),
      );
      expect(() => jsonApi.fetchResource(ResourceType.vehicles, 'vehicle-id'), statusCode(401));
      expect(
        () => jsonApi.updateResource(
          ResourceType.vehicles,
          'vehicle-id',
          attributes: {'name': 'Accord'},
        ),
        statusCode(401),
      );
      expect(() => jsonApi.deleteResource(ResourceType.vehicles, 'vehicle-id'), statusCode(401));
    });

    test('Vehicle Creation, Fetch, List, Update, Delete: Happy Path', () async {
      final session = await signIn(client, 'test-code');

      final created = await jsonApi.createNew(
        ResourceType.vehicles,
        attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        headers: authHeaders(session),
      );

      expect(created.resource.type, ResourceType.vehicles);
      expect(created.resource.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});
      expect(
        created.rawResponse.httpResponse.headers['location']!.single,
        '${testConfig.baseUri}/vehicles/${created.resource.id}',
      );

      final fetched = await jsonApi.fetchResource(
        ResourceType.vehicles,
        created.resource.id,
        headers: authHeaders(session),
      );
      expect(fetched.resource.id, created.resource.id);
      expect(fetched.resource.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});

      final listed = await jsonApi.fetchCollection(
        ResourceType.vehicles,
        headers: authHeaders(session),
      );
      expect(listed.collection.map((r) => r.id), [created.resource.id]);

      final updated = await jsonApi.updateResource(
        ResourceType.vehicles,
        created.resource.id,
        attributes: {'name': 'Accord', 'manufacture_date': '2021-06-02'},
        headers: authHeaders(session),
      );
      expect(updated.resource!.id, created.resource.id);
      expect(updated.resource!.attributes, {'name': 'Accord', 'manufacture_date': '2021-06-02'});

      await jsonApi.deleteResource(
        ResourceType.vehicles,
        created.resource.id,
        headers: authHeaders(session),
      );

      expect(
        () => jsonApi.fetchResource(
          ResourceType.vehicles,
          created.resource.id,
          headers: authHeaders(session),
        ),
        statusCode(404),
      );
      expect(
        (await jsonApi.fetchCollection(
          ResourceType.vehicles,
          headers: authHeaders(session),
        )).collection,
        isEmpty,
      );
    });

    test("Users can't access vehicles they don't own", () async {
      final firstSession = await signIn(client, 'test-code');
      final firstVehicle = await jsonApi.createNew(
        ResourceType.vehicles,
        attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        headers: authHeaders(firstSession),
      );

      final secondClient = TwApiClient(app.urlDesign, app.clientHandler);
      app.googleOAuth.email = 'other@example.com';
      app.googleOAuth.name = 'Other User';
      final secondSession = await signIn(secondClient, 'other-code');

      expect(
        () => jsonApi.fetchResource(
          ResourceType.vehicles,
          firstVehicle.resource.id,
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );
      expect(
        () => jsonApi.updateResource(
          ResourceType.vehicles,
          firstVehicle.resource.id,
          attributes: {'name': 'Accord', 'manufacture_date': '2021-06-02'},
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );
      expect(
        () => jsonApi.deleteResource(
          ResourceType.vehicles,
          firstVehicle.resource.id,
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );

      expect(
        (await jsonApi.fetchCollection(
          ResourceType.vehicles,
          headers: authHeaders(secondSession),
        )).collection,
        isEmpty,
      );

      final fetchedByOwner = await jsonApi.fetchResource(
        ResourceType.vehicles,
        firstVehicle.resource.id,
        headers: authHeaders(firstSession),
      );
      expect(fetchedByOwner.resource.attributes, {
        'name': 'Civic',
        'manufacture_date': '2020-05-01',
      });
    });
  });
}
