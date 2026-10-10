import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:uuid/uuid.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';
import 'package:tw_server/src/auth/sessions_dao.dart';
import 'package:tw_server/src/auth/users_dao.dart';

class GoogleOAuthController(
  final GoogleOAuth googleOAuth,
  final SessionsDAO sessionsDAO,
  final UsersDAO usersDAO,
) {
  Future<Response> start(Request request) async {
    if (request.method.toLowerCase() != 'get') {
      return _text(405, 'Method Not Allowed');
    }

    return _redirect(googleOAuth.startAuthorization(const Uuid().v4()));
  }

  Future<Response> callback(Request request) async {
    final session = await googleOAuth.finishAuthorization(request.uri.queryParameters);
    if (session == null) {
      return _text(400, 'Invalid Google callback.');
    }
    final user = await usersDAO.createOrUpdate(email: session.email, name: session.name);
    final nonce = request.uri.queryParameters['state'];
    if (nonce == null) {
      return _text(400, 'Invalid Google callback.');
    }
    final linkedSession = await sessionsDAO.linkUserByNonce(nonce: nonce, userId: user.id);
    if (linkedSession == null) {
      return _text(400, 'Invalid Google callback.');
    }

    return _text(
      200,
      'Signed in with Google. Session: ${linkedSession.sessionKey}\nEmail: ${session.email}\nName: ${session.name}',
    );
  }
}

Response _text(int statusCode, String body) => Response(
  statusCode,
  Body.text(body, utf8),
  Headers()..addAll({
    'Content-Type': ['text/plain; charset=utf-8'],
  }),
);

Response _redirect(Uri location) => Response(
  302,
  Body(),
  Headers()..addAll({
    'Location': [location.toString()],
  }),
);
