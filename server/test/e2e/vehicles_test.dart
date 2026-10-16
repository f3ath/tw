import 'package:json_api/client.dart' hide Request;
import 'package:json_api/document.dart';
import 'package:test/test.dart';
import 'package:tw_server/tw_server.dart';

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
    'Authorization': ['Bearer ${session.attributes['http_authorization_bearer'] as String}'],
  };

  Matcher statusCode(int expected) => throwsA(
    isA<RequestFailure>().having(
      (r) => r.rawResponse.httpResponse.statusCode,
      'Status Code',
      equals(expected),
    ),
  );

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
      expect(() => jsonApi.fetchCollection('vehicles'), statusCode(401));
      expect(
        () => jsonApi.createNew(
          'vehicles',
          attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        ),
        statusCode(401),
      );
      expect(() => jsonApi.fetchResource('vehicles', 'vehicle-id'), statusCode(401));
      expect(
        () => jsonApi.updateResource('vehicles', 'vehicle-id', attributes: {'name': 'Accord'}),
        statusCode(401),
      );
      expect(() => jsonApi.deleteResource('vehicles', 'vehicle-id'), statusCode(401));
    });

    test('Vehicle Creation, Fetch, List, Update, Delete: Happy Path', () async {
      final session = await signIn(client, 'test-code');

      final created = await jsonApi.createNew(
        'vehicles',
        attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        headers: authHeaders(session),
      );

      expect(created.resource.type, 'vehicles');
      expect(created.resource.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});

      final fetched = await jsonApi.fetchResource(
        'vehicles',
        created.resource.id,
        headers: authHeaders(session),
      );
      expect(fetched.resource.id, created.resource.id);
      expect(fetched.resource.attributes, {'name': 'Civic', 'manufacture_date': '2020-05-01'});

      final listed = await jsonApi.fetchCollection('vehicles', headers: authHeaders(session));
      expect(listed.collection.map((r) => r.id), [created.resource.id]);

      final updated = await jsonApi.updateResource(
        'vehicles',
        created.resource.id,
        attributes: {'name': 'Accord', 'manufacture_date': '2021-06-02'},
        headers: authHeaders(session),
      );
      expect(updated.resource!.id, created.resource.id);
      expect(updated.resource!.attributes, {'name': 'Accord', 'manufacture_date': '2021-06-02'});

      await jsonApi.deleteResource('vehicles', created.resource.id, headers: authHeaders(session));

      expect(
        () => jsonApi.fetchResource('vehicles', created.resource.id, headers: authHeaders(session)),
        statusCode(404),
      );
      expect(
        (await jsonApi.fetchCollection('vehicles', headers: authHeaders(session))).collection,
        isEmpty,
      );
    });

    test("Users can't access vehicles they don't own", () async {
      final firstSession = await signIn(client, 'test-code');
      final firstVehicle = await jsonApi.createNew(
        'vehicles',
        attributes: {'name': 'Civic', 'manufacture_date': '2020-05-01'},
        headers: authHeaders(firstSession),
      );

      final secondClient = TwApiClient(app.urlDesign, app.clientHandler);
      app.googleOAuth.email = 'other@example.com';
      app.googleOAuth.name = 'Other User';
      final secondSession = await signIn(secondClient, 'other-code');

      expect(
        () => jsonApi.fetchResource(
          'vehicles',
          firstVehicle.resource.id,
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );
      expect(
        () => jsonApi.updateResource(
          'vehicles',
          firstVehicle.resource.id,
          attributes: {'name': 'Accord', 'manufacture_date': '2021-06-02'},
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );
      expect(
        () => jsonApi.deleteResource(
          'vehicles',
          firstVehicle.resource.id,
          headers: authHeaders(secondSession),
        ),
        statusCode(404),
      );

      expect(
        (await jsonApi.fetchCollection('vehicles', headers: authHeaders(secondSession))).collection,
        isEmpty,
      );

      final fetchedByOwner = await jsonApi.fetchResource(
        'vehicles',
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
