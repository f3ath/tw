import 'package:app/app/app.dart';
import 'package:app/data/auth/api_client_adapter.dart';
import 'package:app/data/auth/backend_auth_service.dart';
import 'package:app/data/auth/login_window/open_login_window.dart';
import 'package:app/data/backend_operation_repo.dart';
import 'package:app/data/backend_schedule_repo.dart';
import 'package:app/data/backend_service_repo.dart';
import 'package:app/data/backend_vehicle_repo.dart';
import 'package:app/testing/samples.dart' as samples;
import 'package:app/testing/stub.dart' as stub;
import 'package:http/http.dart' as http;
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/routing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const fake = bool.fromEnvironment('FAKE');
  runApp(fake ? _fakeApp() : _realApp());
}

TwApp _realApp() {
  const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.twdiy.app/api/v0');
  final baseUri = Uri.parse(apiUrl);
  final uriDesign = StandardUriDesign(baseUri);
  final handler = http.Client().sendInterop;
  final twApiClient = TwApiClient(uriDesign, handler);
  return TwApp(
    authService: BackendAuthService(
      authApi: ApiClientAdapter(
        twApiClient,
        preferences: SharedPreferencesAsync(),
        baseUri: baseUri,
      ),
      newWindow: openLoginWindow,
    ),
    scheduleRepo: BackendScheduleRepo(twApiClient),
    serviceRepo: BackendServiceRepo(twApiClient),
    operationRepo: BackendOperationRepo(twApiClient),
    vehicleRepo: BackendVehicleRepo(twApiClient),
  );
}

TwApp _fakeApp() {
  final scheduleRepo = stub.InMemoryScheduleRepo(initialSchedules: samples.sampleSchedules);
  final serviceRepo = stub.InMemoryServiceRepo(initialServices: samples.sampleServices);
  return TwApp(
    authService: stub.InMemoryAuthService(user: samples.sampleUser),
    vehicleRepo: stub.InMemoryVehicleRepo(initialVehicles: samples.sampleVehicles),
    scheduleRepo: scheduleRepo,
    serviceRepo: serviceRepo,
    operationRepo: stub.InMemoryOperationRepo(
      initialOperations: samples.sampleOperations,
      serviceRepo: serviceRepo,
      scheduleRepo: scheduleRepo,
    ),
  );
}
