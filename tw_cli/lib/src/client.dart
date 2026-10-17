import 'package:http/http.dart' as http;
import 'package:http_interop/http_interop.dart';
import 'package:http_interop_http/http_interop_http.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:tw_server/tw_server.dart';

import 'models.dart';
import 'session_store.dart';

abstract interface class TwClient() {
  Future<SessionInfo?> createSession();

  Future<List<SessionInfo>> listSessions();

  Future<void> deleteSession(String id);

  Future<VehicleInfo> createVehicle({required String name, required DateTime manufactureDate});

  Future<List<VehicleInfo>> listVehicles();

  Future<VehicleInfo> fetchVehicle(String id);

  Future<VehicleInfo?> updateVehicle(String id, {String? name, DateTime? manufactureDate});

  Future<void> deleteVehicle(String id);

  Future<ScheduleInfo> createSchedule(
    String vehicleId, {
    required String name,
    required int intervalMiles,
    required int intervalMonths,
    required String details,
  });

  Future<List<ScheduleInfo>> listSchedules(String vehicleId);

  Future<ScheduleInfo?> updateSchedule(
    String vehicleId,
    String scheduleId, {
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    String? details,
  });

  Future<void> deleteSchedule(String id);
}

class TwApiClientAdapter(final TwApiClient _client) implements TwClient {
  factory forServer({required Uri baseUri, required SessionStore sessionStore}) {
    return TwApiClientAdapter(
      TwApiClient(StandardUriDesign(baseUri), _storedSessionHttpHandler(sessionStore)),
    );
  }

  @override
  Future<SessionInfo?> createSession() async {
    final resource = await _client.createSession();
    return resource == null ? null : _sessionInfo(resource);
  }

  @override
  Future<List<SessionInfo>> listSessions() async =>
      (await _client.listSessions()).map(_sessionInfo).toList();

  @override
  Future<void> deleteSession(String id) => _client.deleteSessionById(id);

  @override
  Future<VehicleInfo> createVehicle({
    required String name,
    required DateTime manufactureDate,
  }) async =>
      _vehicleInfo(await _client.createVehicle(name: name, manufactureDate: manufactureDate));

  @override
  Future<List<VehicleInfo>> listVehicles() async =>
      (await _client.listVehicles()).map(_vehicleInfo).toList();

  @override
  Future<VehicleInfo> fetchVehicle(String id) async => _vehicleInfo(await _client.fetchVehicle(id));

  @override
  Future<VehicleInfo?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final resource = await _client.updateVehicle(id, name: name, manufactureDate: manufactureDate);
    return resource == null ? null : _vehicleInfo(resource);
  }

  @override
  Future<void> deleteVehicle(String id) => _client.deleteVehicle(id);

  @override
  Future<ScheduleInfo> createSchedule(
    String vehicleId, {
    required String name,
    required int intervalMiles,
    required int intervalMonths,
    required String details,
  }) async => _scheduleInfo(
    await _client.createSchedule(
      vehicleId,
      name: name,
      intervalMiles: intervalMiles,
      intervalMonths: intervalMonths,
      details: details,
    ),
  );

  @override
  Future<List<ScheduleInfo>> listSchedules(String vehicleId) async =>
      (await _client.listSchedules(vehicleId)).map(_scheduleInfo).toList();

  @override
  Future<ScheduleInfo?> updateSchedule(
    String vehicleId,
    String scheduleId, {
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    String? details,
  }) async {
    final resource = await _client.updateSchedule(
      vehicleId,
      scheduleId,
      name: name,
      intervalMiles: intervalMiles,
      intervalMonths: intervalMonths,
      details: details,
    );
    return resource == null ? null : _scheduleInfo(resource);
  }

  @override
  Future<void> deleteSchedule(String id) => _client.deleteSchedule(id);
}

Handler _storedSessionHttpHandler(SessionStore sessionStore) => (request) async {
  final session = await sessionStore.read();
  final bearer = session?.bearer;
  if (bearer != null && bearer.isNotEmpty && !request.headers.containsKey('Authorization')) {
    request.headers['Authorization'] = ['Bearer $bearer'];
  }

  final client = http.Client();
  try {
    return await client.handleInterop(request);
  } finally {
    client.close();
  }
};

SessionInfo _sessionInfo(Resource resource) {
  final redirect = resource.attributes['redirect'] as String?;
  return SessionInfo(
    id: resource.id,
    bearer: resource.attributes['http_authorization_bearer'] as String?,
    redirect: redirect == null ? null : Uri.parse(redirect),
  );
}

VehicleInfo _vehicleInfo(Resource resource) => VehicleInfo(
  id: resource.id,
  name: resource.attributes['name'] as String,
  manufactureDate: resource.attributes['manufacture_date'] as String,
);

ScheduleInfo _scheduleInfo(Resource resource) => ScheduleInfo(
  id: resource.id,
  vehicleId: resource.attributes['vehicle_id'] as String,
  name: resource.attributes['name'] as String,
  intervalMiles: resource.attributes['interval_miles'] as int,
  intervalMonths: resource.attributes['interval_months'] as int,
  details: resource.attributes['details'] as String,
);
