import 'dart:convert';

import 'package:http_interop/http_interop.dart';

Future<Response> plain404(Request rq) async =>
    Response(404, Body.text('404 Not Found', utf8), Headers());
