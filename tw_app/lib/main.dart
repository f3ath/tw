import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:tw_app/app/tw_app.dart';
import 'package:tw_app/data/auth/backend_auth_service.dart';
import 'package:tw_app/data/auth/login_window/open_login_window.dart';
import 'package:tw_app/data/auth/tw_auth_api_adapter.dart';
import 'package:tw_app/testing/stub.dart';

void main() {
  final fake = true;
  final httpClient = http.Client();
  final authApi = TwAuthApiAdapter(
    TwApiClient(
      StandardUriDesign(Uri.parse('http://localhost:8080/api/v0')),
      httpClient.sendInterop,
    ),
  );
  final authService = BackendAuthService(authApi: authApi, newWindow: openLoginWindow);

  runApp(TwApp(authService: fake ? AuthServiceStub() : authService));
}
