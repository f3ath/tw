import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';

import 'resource_type.dart';
import 'user.dart';

class TwApiClient(UriDesign urlDesign, Handler handler) {
  this {
    _jsonApi = RoutingClient(urlDesign.uri, Client(_authenticated(handler)));
  }

  late final RoutingClient _jsonApi;
  Resource? _session;

  Future<Resource?> createSession() async {
    final response = await _jsonApi.createNew(ResourceType.sessions);
    return _session = response.resource;
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection(ResourceType.sessions)).collection;

  Future<Resource> fetchSession(String id) async =>
      (await _jsonApi.fetchResource(ResourceType.sessions, id)).resource;

  Future<Resource> fetchCurrentSession() async {
    final session = _session;
    if (session == null) {
      throw StateError('No session to fetch');
    }
    return fetchSession(session.id);
  }

  Future<User?> fetchCurrentUser() async {
    final session = _session;
    if (session == null) {
      throw StateError('No session to fetch user for');
    }
    final resource = (await _jsonApi.fetchRelatedResource(
      ResourceType.sessions,
      session.id,
      'user',
    )).resource;
    return resource == null ? null : User.fromResource(resource);
  }

  Future<Resource> createVehicle({required String name, required DateTime manufactureDate}) async {
    final response = await _jsonApi.createNew(
      ResourceType.vehicles,
      attributes: {'name': name, 'manufacture_date': _date(manufactureDate)},
    );
    return response.resource;
  }

  Future<List<Resource>> listVehicles() async =>
      (await _jsonApi.fetchCollection(ResourceType.vehicles)).collection;

  Future<Resource> fetchVehicle(String id) async =>
      (await _jsonApi.fetchResource(ResourceType.vehicles, id)).resource;

  Future<Resource?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final attributes = <String, Object?>{};
    if (name != null) {
      attributes['name'] = name;
    }
    if (manufactureDate != null) {
      attributes['manufacture_date'] = _date(manufactureDate);
    }
    final response = await _jsonApi.updateResource(
      ResourceType.vehicles,
      id,
      attributes: attributes,
    );
    return response.resource;
  }

  Future<void> deleteVehicle(String id) async {
    await _jsonApi.deleteResource(ResourceType.vehicles, id);
  }

  Future<List<Resource>> listSchedules(String vehicleId) async =>
      (await _jsonApi.fetchRelatedCollection(
        ResourceType.vehicles,
        vehicleId,
        'schedule',
      )).collection;

  Future<Resource> createSchedule(
    String vehicleId, {
    required String name,
    required int intervalMiles,
    required int intervalMonths,
    required String details,
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.schedules,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: {
        'name': name,
        'interval_miles': intervalMiles,
        'interval_months': intervalMonths,
        'details': details,
      },
    );
    return response.resource;
  }

  Future<Resource?> updateSchedule(
    String vehicleId,
    String scheduleId, {
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    String? details,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.schedules,
      scheduleId,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: <String, Object?>{
        'name': ?name,
        'interval_miles': ?intervalMiles,
        'interval_months': ?intervalMonths,
        'details': ?details,
      },
    );
    return response.resource;
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _jsonApi.deleteResource(ResourceType.schedules, scheduleId);
  }

  Future<List<Resource>> listServices(String vehicleId) async =>
      (await _jsonApi.fetchRelatedCollection(
        ResourceType.vehicles,
        vehicleId,
        'service',
      )).collection;

  Future<Resource> createService(
    String vehicleId, {
    required DateTime date,
    required int mileage,
    String details = '',
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.services,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: {'date': _date(date), 'mileage': mileage, 'details': details},
    );
    return response.resource;
  }

  Future<Resource?> updateService(
    String vehicleId,
    String serviceId, {
    required DateTime date,
    required int mileage,
    String? details,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.services,
      serviceId,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: <String, Object?>{'date': _date(date), 'mileage': mileage, 'details': ?details},
    );
    return response.resource;
  }

  Future<void> deleteService(String serviceId) async {
    await _jsonApi.deleteResource(ResourceType.services, serviceId);
  }

  Future<void> deleteSession() async {
    final session = _session;
    if (session == null) {
      throw StateError('No session to delete');
    }
    await deleteSessionById(session.id);
  }

  Future<void> deleteSessionById(String id) async {
    await _jsonApi.deleteResource(ResourceType.sessions, id);
    if (_session?.id == id) {
      _session = null;
    }
  }

  Handler _authenticated(Handler inner) => (request) {
    final bearer = _session?.attributes['key'] as String?;
    if (bearer != null) {
      request.headers['Authorization'] = ['Bearer $bearer'];
    }
    return inner(request);
  };

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}
