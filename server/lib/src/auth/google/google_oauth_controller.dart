import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:uuid/uuid.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';

class GoogleOAuthController(final GoogleOAuth googleOAuth) {
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

    return _text(
      200,
      'Signed in with Google. Session: ${session.id}\nEmail: ${session.email}\nName: ${session.name}',
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
