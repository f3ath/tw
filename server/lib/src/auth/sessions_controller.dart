import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:uuid/uuid.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/google/google_oauth.dart';

class SessionsController(final GoogleOAuth _googleOAuth) extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    return Response(401, Body.text('Unauthorized', utf8), Headers());
  }

  @override
  Future<Response> createResource(Request request, Target target) async {
    final uri = _googleOAuth.startAuthorization(const Uuid().v4());
    return created(
      OutboundDataDocument.resource(
        Resource(target.type, '1')..attributes['redirect'] = uri.toString(),
      ),
      '/sessions/1',
    );
  }
}
