import 'dart:convert';

import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/server.dart';


Response plain(int statusCode, String body) => Response(
  statusCode,
  Body.text(body, utf8),
  Headers()..addAll({
    'Content-Type': ['text/plain; charset=utf-8'],
  }),
);

// JSON API responses

Response unauthorized([OutboundErrorDocument? document]) => response(401, document: document);
