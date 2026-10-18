import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_shared/api.dart';

/// Controls access to API routes. Controllers enforce resource ownership.
class const SessionAccessPolicy() {
  bool allows(JsonApiRequest request, SessionRecord? session) {
    // Anyone may create a session.
    if (request case CreateResourceRequest(target: CollectionTarget(type: ResourceType.sessions))) {
      return true;
    }

    if (session == null) return false;

    // A session linked to a user may access authenticated routes.
    if (session.userId != null) return true;

    // A pending session may only fetch itself and its related user.
    return switch (request) {
      FetchResourceRequest(target: ResourceTarget(type: ResourceType.sessions, :final id)) =>
        id == session.id,
      FetchRelatedRequest(
        target: RelatedTarget(type: ResourceType.sessions, :final id, relationship: 'user'),
      ) =>
        id == session.id,
      _ => false,
    };
  }
}
