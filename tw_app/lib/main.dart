import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/client.dart';
import 'package:json_api/routing.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/data/auth/api_client_adapter.dart';
import 'package:tw_app/data/auth/backend_auth_service.dart';
import 'package:tw_app/data/auth/login_window/open_login_window.dart';
import 'package:tw_app/testing/stub.dart' as stub;

import 'data/api_client.dart';

void main() {
  final fake = false;
  final authApi = ApiClientAdapter(
    ApiClient(
      StandardUriDesign(Uri.parse('http://localhost:8080/api/v0')).uri,
      Client(http.Client().sendInterop),
    ),
  );
  final authService = BackendAuthService(authApi: authApi, newWindow: openLoginWindow);

  runApp(
    TwApp(
      authService: fake ? stub.AuthServiceStub() : authService,
      vehicleRepo: stub.VehicleRepoStub(),
    ),
  );
}
