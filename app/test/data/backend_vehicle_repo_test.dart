import 'dart:convert';

import 'package:app/app/create_conflict.dart';
import 'package:app/data/backend_vehicle_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';

void main() {
  for (final status in [409, 503]) {
    test('sends the draft ID and handles HTTP $status', () async {
      const id = '12345678-abcd-4abc-8abc-1234567890ab';
      final httpClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v0/vehicles');
        expect(jsonDecode(request.body), containsPair('data', containsPair('id', id)));
        return http.Response('', status);
      });
      addTearDown(httpClient.close);
      final client = TwApiClient(
        StandardUriDesign(Uri.parse('https://example.test/api/v0')),
        httpClient.sendInterop,
      );
      final repo = BackendVehicleRepo(client);

      await expectLater(
        repo.create(id: id, name: 'Civic', manufactureDate: CalendarDate(2020), mileageUnit: .mi),
        throwsA(status == 409 ? isA<CreateConflict>() : isA<RequestFailure>()),
      );
    });
  }
}
