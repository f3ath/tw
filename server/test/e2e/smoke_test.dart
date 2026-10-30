import 'package:json_api/client.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  test('Authenticate, add a vehicle, rename it, and log off', () async {
    final testServer = await startTestServer();
    addTearDown(testServer.stop);
    final client = testServer.client;

    await client.createSession();
    expect((await testServer.googleCallback('test-code')).statusCode, 200);
    final user = await client.fetchCurrentUser();
    expect(user!.email, 'user@example.com');

    final vehicle = await client.createVehicle(
      name: 'Civic',
      manufactureDate: DateTime(2020, 5, 1),
    );
    expect(vehicle.attributes['name'], 'Civic');

    await client.updateVehicle(vehicle.id, name: 'My Civic');
    final renamed = await client.fetchVehicle(vehicle.id);
    expect(renamed.attributes['name'], 'My Civic');
    expect(renamed.attributes['manufacture_date'], '2020-05-01');

    await client.deleteSession();
    await expectLater(
      client.listVehicles(),
      throwsA(
        isA<RequestFailure>().having(
          (failure) => failure.rawResponse.httpResponse.statusCode,
          'Status Code',
          401,
        ),
      ),
    );
  });
}
