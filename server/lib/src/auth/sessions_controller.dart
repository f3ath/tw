import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';

class SessionsController(final GoogleOAuth _googleOAuth, final SessionsDAO _sessionsDAO)
    extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final authenticatedSession = await _authenticatedSession(request);
    if (authenticatedSession?.userId == null) {
      return Response(401, Body.text('Unauthorized', utf8), Headers());
    }
    final sessions = await _sessionsDAO.fetchByUserId(authenticatedSession!.userId!);
    return ok(
      OutboundDataDocument.collection(sessions.map((session) => _resource(target, session))),
    );
  }

  @override
  Future<Response> createResource(Request request, Target target) async {
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
    final authenticatedSession = await _authenticatedSession(request);
    if (authenticatedSession == null) {
      return Response(401, Body.text('Unauthorized', utf8), Headers());
    }
    final session = await _sessionsDAO.fetch(target.id);
    if (session == null) {
      return notFound();
    }
    if (authenticatedSession.id != session.id &&
        (authenticatedSession.userId == null || authenticatedSession.userId != session.userId)) {
      return Response(401, Body.text('Unauthorized', utf8), Headers());
    }
    await _sessionsDAO.delete(target.id);
    return noContent();
  }

  Future<SessionRecord?> _authenticatedSession(Request request) async {
    final authorization = request.headers['Authorization']?.singleOrNull;
    if (authorization == null) {
      return null;
    }
    const prefix = 'Bearer ';
    if (!authorization.startsWith(prefix)) {
      return null;
    }
    return _sessionsDAO.fetchBySessionKey(authorization.substring(prefix.length));
  }

  Resource _resource(Target target, SessionRecord session) =>
      Resource(target.type, session.id)
        ..attributes['http_authorization_bearer'] = session.sessionKey;
}
