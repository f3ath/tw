import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/data/auth/api_client_adapter.dart';
import 'package:tw_app/data/auth/backend_auth_service.dart';
import 'package:tw_app/data/auth/login_window/open_login_window.dart';
import 'package:tw_app/data/backend_vehicle_repo.dart';
import 'package:tw_app/testing/stub.dart' as stub;

void main() {
  final fake = false;
  final uriDesign = StandardUriDesign(Uri.parse('http://localhost:8080/api/v0'));
  final handler = http.Client().sendInterop;
  final twApiClient = TwApiClient(uriDesign, handler);

  runApp(
    TwApp(
      authService: fake
          ? stub.AuthServiceStub()
          : BackendAuthService(authApi: ApiClientAdapter(twApiClient), newWindow: openLoginWindow),
      vehicleRepo: fake ? stub.VehicleRepoStub() : BackendVehicleRepo(twApiClient),
    ),
  );
}
