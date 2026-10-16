import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/http/context.dart';
import 'package:tw_server/src/json_api/base_controller.dart';

class SessionsController(final GoogleOAuth _googleOAuth, final SessionsDAO _sessionsDAO)
    extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final sessions = await _sessionsDAO.fetchByUserId(Context(request).userId);
    return ok(
      OutboundDataDocument.collection(sessions.map((session) => _resource(target, session))),
    );
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
        _resource(target, session)
          ..attributes['redirect'] = uri.toString()
          ..attributes['http_authorization_bearer'] = session.sessionKey,
      ),
      '/${target.type}/${session.id}',
    );
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _sessionsDAO.delete(id: target.id, userId: Context(request).userId)) {
      return notFound();
    }
    return noContent();
  }

  Resource _resource(Target target, SessionRecord session) =>
      Resource(target.type, session.id)
        ..attributes['http_authorization_bearer'] = session.sessionKey;
}
