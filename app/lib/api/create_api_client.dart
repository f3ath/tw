import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';

TwApiClient createApiClient(http.Client transport) => TwApiClient(
  StandardUriDesign(
    Uri.parse(
      const String.fromEnvironment('TW_SERVER_URL', defaultValue: 'http://localhost:8080/api/v0'),
    ),
  ),
  (request) => transport.handleInterop(request).timeout(const Duration(seconds: 15)),
);
