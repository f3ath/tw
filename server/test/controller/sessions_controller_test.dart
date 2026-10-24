import 'package:http_interop/extensions.dart';
import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:server/src/auth/google/google_oauth.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/auth/sessions_controller.dart';
import 'package:server/src/auth/sessions_dao.dart';
import 'package:shared/api.dart';
import 'package:test/test.dart';

import '../doubles/fake_sessions_dao.dart';
import '../doubles/fake_users_dao.dart';

void main() {
  group('SessionsController', () {
    late FakeSessionsDAO sessions;
    late SessionsController controller;
    const pending = SessionRecord(id: 'session-id', sessionKey: 'session-key', nonce: 'nonce');
    const linked = SessionRecord(id: 'session-id', sessionKey: 'session-key', userId: 'owner-id');

    setUp(() {
      sessions = FakeSessionsDAO();
      controller = SessionsController(
        UnusedGoogleOAuth(),
        sessions,
        FakeUsersDAO(),
        StandardUriDesign(Uri(path: '/api/v0')).uri,
      );
    });

    Future<Response> fetch({
      String id = 'session-id',
      String sessionKey = 'session-key',
      String? userId,
    }) {
      final request = Request('get', Uri(path: '/api/v0/sessions/$id'), Body.empty(), Headers())
        ..sessionKey = sessionKey;
      if (userId != null) request.userId = userId;
      return controller.fetchResource(request, ResourceTarget(ResourceType.sessions, id));
    }

    group('fetchResource', () {
      test('returns 404 when the requested session does not exist', () async {
        final response = await fetch(id: 'missing-id');

        expect(response.statusCode, 404);
        expect(sessions.fetchedIds, ['missing-id']);
      });

      test('returns a pending session to its bearer with an empty user relationship', () async {
        sessions.records[pending.id] = pending;

        final resource = await _resource(await fetch());

        expect(resource.type, ResourceType.sessions);
        expect(resource.id, pending.id);
        expect(resource.attributes, {'key': pending.sessionKey});
        expect(resource.relationships['user'], isA<ToOne>());
        expect(resource.relationships['user'], isEmpty);
      });

      test('returns a linked session to its bearer without requiring a caller user ID', () async {
        sessions.records[linked.id] = linked;

        final resource = await _resource(await fetch());

        expect(resource.id, linked.id);
        expect(resource.attributes, {'key': linked.sessionKey});
        final user = resource.relationships['user']!.single;
        expect(user.type, ResourceType.users);
        expect(user.id, linked.userId);
      });

      test('returns a session owned by the caller even with a different bearer key', () async {
        sessions.records[linked.id] = linked;

        final resource = await _resource(
          await fetch(sessionKey: 'another-session-key', userId: linked.userId),
        );

        expect(resource.id, linked.id);
        expect(resource.attributes, {'key': linked.sessionKey});
      });

      test('returns 404 for a session belonging to another user', () async {
        sessions.records[linked.id] = linked;

        final response = await fetch(sessionKey: 'another-session-key', userId: 'another-user-id');

        expect(response.statusCode, 404);
      });

      test('returns 404 for a pending session with a different bearer key', () async {
        sessions.records[pending.id] = pending;

        final response = await fetch(sessionKey: 'another-session-key', userId: 'caller-id');

        expect(response.statusCode, 404);
      });
    });
  });
}

Future<Resource> _resource(Response response) async {
  expect(response.statusCode, 200);
  return InboundDocument(await response.body.decodeJson()).dataAsResource();
}

class UnusedGoogleOAuth() implements GoogleOAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
