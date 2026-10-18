import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/auth/session_access_policy.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_shared/api.dart';

Request httpRequest(String method) => Request(method, Uri(path: '/'), Body(), Headers());

CreateResourceRequest create(String type) => CreateResourceRequest(
  httpRequest('post'),
  CollectionTarget(type),
  InboundDocument({
    'data': {'type': type},
  }),
);

void main() {
  const policy = SessionAccessPolicy();
  const pending = SessionRecord(id: 'session-id', sessionKey: 'key');
  const authenticated = SessionRecord(id: 'session-id', sessionKey: 'key', userId: 'user-id');
  final ownSession = FetchResourceRequest(
    httpRequest('get'),
    ResourceTarget(ResourceType.sessions, pending.id),
  );
  final ownUser = FetchRelatedRequest(
    httpRequest('get'),
    RelatedTarget(ResourceType.sessions, pending.id, 'user'),
  );
  final protectedRequests = <JsonApiRequest>[
    FetchCollectionRequest(httpRequest('get'), CollectionTarget(ResourceType.sessions)),
    FetchResourceRequest(httpRequest('get'), ResourceTarget(ResourceType.sessions, 'other-id')),
    FetchRelatedRequest(
      httpRequest('get'),
      RelatedTarget(ResourceType.sessions, 'other-id', 'user'),
    ),
    FetchRelatedRequest(
      httpRequest('get'),
      RelatedTarget(ResourceType.sessions, pending.id, 'unknown'),
    ),
    FetchRelationshipRequest(
      httpRequest('get'),
      RelationshipTarget(ResourceType.sessions, pending.id, 'user'),
    ),
    DeleteResourceRequest(httpRequest('delete'), ResourceTarget(ResourceType.sessions, pending.id)),
    FetchResourceRequest(httpRequest('get'), ResourceTarget(ResourceType.vehicles, pending.id)),
    create(ResourceType.vehicles),
  ];

  group('SessionAccessPolicy', () {
    test('Anyone may create a session', () {
      for (final session in [null, pending, authenticated]) {
        expect(policy.allows(create(ResourceType.sessions), session), isTrue);
      }
    });

    test('A pending session may fetch itself and its related user', () {
      expect(policy.allows(ownSession, pending), isTrue);
      expect(policy.allows(ownUser, pending), isTrue);
    });

    test('A session linked to a user may access authenticated routes', () {
      for (final request in [ownSession, ownUser, ...protectedRequests]) {
        expect(policy.allows(request, authenticated), isTrue, reason: '${request.runtimeType}');
      }
    });

    test('Requests without a valid session cannot access protected routes', () {
      for (final request in [ownSession, ownUser, ...protectedRequests]) {
        expect(policy.allows(request, null), isFalse, reason: '${request.runtimeType}');
      }
    });

    test('A pending session cannot access other protected routes', () {
      for (final request in protectedRequests) {
        expect(policy.allows(request, pending), isFalse, reason: '${request.runtimeType}');
      }
    });
  });
}
