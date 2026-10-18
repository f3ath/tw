import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/request_ext.dart';
import 'package:tw_server/src/auth/session_resource.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';
import 'package:tw_server/src/json_api/base_controller.dart';
import 'package:tw_server/src/json_api/resource_type.dart';

class SessionsController(
  final GoogleOAuth _googleOAuth,
  final SessionsDAO _sessionsDAO,
  final UsersDAO _usersDAO,
  final UriBuilder _uriFor,
) extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final sessions = await _sessionsDAO.fetchByUserId(request.userId);
    return ok(OutboundDataDocument.collection(sessions.map(SessionResource.new)));
  }

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final session = await _sessionsDAO.create();
    final uri = _googleOAuth.startAuthorization(session.nonce!);
    return created(
      OutboundDataDocument.resource(
        SessionResource(session)..attributes['redirect'] = uri.toString(),
      ),
      _uriFor(ResourceTarget(target.type, session.id)).toString(),
    );
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _sessionsDAO.delete(id: target.id, userId: request.userId)) {
      return notFound();
    }
    return noContent();
  }

  @override
  Future<Response> fetchResource(Request request, ResourceTarget target) async {
    final session = await _fetchAccessibleSession(request, target.id);
    if (session == null) return notFound();
    return ok(OutboundDataDocument.resource(SessionResource(session)));
  }

  @override
  Future<Response> fetchRelated(Request request, RelatedTarget target) async {
    if (target.relationship != 'user') return notFound();
    final session = await _fetchAccessibleSession(request, target.id);
    if (session == null) return notFound();
    final userId = session.userId;
    if (userId == null) return ok(OutboundDataDocument.resource(null));
    final user = await _usersDAO.fetch(userId);
    if (user == null) return notFound();
    return ok(
      OutboundDataDocument.resource(
        Resource(ResourceType.users, user.id)
          ..attributes['email'] = user.email
          ..attributes['name'] = user.name,
      ),
    );
  }

  Future<SessionRecord?> _fetchAccessibleSession(Request request, String id) async {
    final session = await _sessionsDAO.fetch(id);
    if (session == null) return null;
    if (session.sessionKey == request.sessionKey) return session;
    if (session.userId != null && session.userId == request.userId) return session;
    return null;
  }
}
