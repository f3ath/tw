import 'dart:convert';

import 'package:app/app/create_conflict.dart';
import 'package:app/data/backend_operation_repo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';

void main() {
  for (final linked in [false, true]) {
    for (final status in [409, 503]) {
      test('sends the draft ID and handles HTTP $status (linked: $linked)', () async {
        const id = '12345678-abcd-4abc-8abc-1234567890ab';
        const serviceId = '22345678-abcd-4abc-8abc-1234567890ab';
        const scheduleId = '32345678-abcd-4abc-8abc-1234567890ab';
        final httpClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v0/operations');
          expect(
            jsonDecode(request.body),
            containsPair(
              'data',
              allOf(
                containsPair('id', id),
                containsPair('relationships', {
                  'service': {
                    'data': {'type': ResourceType.services, 'id': serviceId},
                  },
                  if (linked)
                    'schedule': {
                      'data': {'type': ResourceType.schedules, 'id': scheduleId},
                    },
                }),
              ),
            ),
          );
          return http.Response('', status);
        });
        addTearDown(httpClient.close);
        final client = TwApiClient(
          StandardUriDesign(Uri.parse('https://example.test/api/v0')),
          httpClient.sendInterop,
        );
        final repo = BackendOperationRepo(client);

        await expectLater(
          linked
              ? repo.createFromSchedule(serviceId, id: id, scheduleId: scheduleId)
              : repo.create(serviceId, id: id, name: 'Inspection'),
          throwsA(status == 409 ? isA<CreateConflict>() : isA<RequestFailure>()),
        );
      });
    }
  }
}
