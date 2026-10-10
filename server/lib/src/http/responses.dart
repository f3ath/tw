import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/server.dart';

Future<Response> plainNotFound(Request rq) async =>
    Response(404, Body.text('404 Not Found', utf8), Headers());

Response unauthorized([OutboundErrorDocument? document]) =>
    response(401, document: document);