import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';

class TwApiClient(UriDesign urlDesign, Handler handler) {
  this {
    _jsonApi = RoutingClient(urlDesign.uri, Client(_authenticated(handler)));
  }

  late final RoutingClient _jsonApi;
  String? _token;

  // Sessions

  Future<Session> createSession() async {
    final response = await _jsonApi.createNew(ResourceType.sessions);
    final resource = response.resource;
    final token = resource.attributes['token'];
    if (token is! String) {
      throw InvalidResponse('Missing session token');
    }
    _token = token;
    return Session.fromResource(resource);
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection(ResourceType.sessions)).collection;

  Future<Session> fetchSession(String id) async {
    final r = await _jsonApi.fetchResource(ResourceType.sessions, id);
    return Session.fromResource(r.resource);
  }

  Future<Session> fetchCurrentSession() async {
    if (_token == null) {
      throw StateError('Unauthenticated');
    }
    return fetchSession('current');
  }

  Future<void> deleteCurrentSession() async {
    if (_token == null) {
      throw StateError('Unauthenticated');
    }
    try {
      await _jsonApi.deleteResource(ResourceType.sessions, 'current');
    } finally {
      _token = null;
    }
  }

  Future<void> deleteSessionById(String id) async =>
      await _jsonApi.deleteResource(ResourceType.sessions, id);

  // Users

  Future<User?> fetchCurrentUser() async {
    if (_token == null) {
      throw StateError('Unauthenticated');
    }
    final resource = (await _jsonApi.fetchRelatedResource(
      ResourceType.sessions,
      'current',
      'user',
    )).resource;
    return resource == null ? null : User.fromResource(resource);
  }

  // Vehicles

  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    DistanceUnit distanceUnit = DistanceUnit.mi,
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.vehicles,
      attributes: {
        'name': name,
        'manufacture_date': _date(manufactureDate),
        'distance_unit': distanceUnit.name,
      },
    );
    return Vehicle.fromResource(response.resource);
  }

  Future<List<Vehicle>> listVehicles() async =>
      (await _jsonApi.fetchCollection(ResourceType.vehicles)).collection
          .map(Vehicle.fromResource)
          .toList();

  Future<Vehicle> fetchVehicle(String id) async =>
      Vehicle.fromResource((await _jsonApi.fetchResource(ResourceType.vehicles, id)).resource);

  Future<Vehicle?> updateVehicle(String id, {String? name, DateTime? manufactureDate}) async {
    final response = await _jsonApi.updateResource(
      ResourceType.vehicles,
      id,
      attributes: {
        'name': ?name,
        if (manufactureDate != null) 'manufacture_date': _date(manufactureDate),
      },
    );
    final resource = response.resource;
    return resource == null ? null : Vehicle.fromResource(resource);
  }

  Future<void> deleteVehicle(String id) async {
    await _jsonApi.deleteResource(ResourceType.vehicles, id);
  }

  // Schedules

  Future<List<Schedule>> listSchedules(String vehicleId) async =>
      (await _jsonApi.fetchRelatedCollection(
        ResourceType.vehicles,
        vehicleId,
        'schedule',
      )).collection.map(Schedule.fromResource).toList();

  Future<Schedule> createSchedule(
    String vehicleId, {
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.schedules,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: {
        'name': name,
        'interval_distance': intervalDistance,
        'interval_months': intervalMonths,
        'details': details,
      },
    );
    return Schedule.fromResource(response.resource);
  }

  Future<Schedule?> updateSchedule(
    String scheduleId, {
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    String? details,
    bool? isArchived,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.schedules,
      scheduleId,
      attributes: {
        'name': name,
        'interval_distance': intervalDistance,
        'interval_months': intervalMonths,
        'details': ?details,
        'is_archived': ?isArchived,
      },
    );
    final resource = response.resource;
    return resource == null ? null : Schedule.fromResource(resource);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _jsonApi.deleteResource(ResourceType.schedules, scheduleId);
  }

  // Services

  Future<List<Service>> listServices(String vehicleId) async =>
      (await _jsonApi.fetchRelatedCollection(
        ResourceType.vehicles,
        vehicleId,
        'service',
      )).collection.map(Service.fromResource).toList();

  Future<Service> createService(
    String vehicleId, {
    required DateTime date,
    required int odometer,
    String details = '',
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.services,
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
      attributes: {'date': _date(date), 'odometer': odometer, 'details': details},
    );
    return Service.fromResource(response.resource);
  }

  Future<Service?> updateService(
    String serviceId, {
    required DateTime date,
    required int odometer,
    String? details,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.services,
      serviceId,
      attributes: {'date': _date(date), 'odometer': odometer, 'details': ?details},
    );
    final resource = response.resource;
    return resource == null ? null : Service.fromResource(resource);
  }

  Future<void> deleteService(String serviceId) async {
    await _jsonApi.deleteResource(ResourceType.services, serviceId);
  }

  // Operations

  Future<List<Operation>> listOperations(String serviceId) async =>
      (await _jsonApi.fetchRelatedCollection(
        ResourceType.services,
        serviceId,
        'operations',
      )).collection.map(Operation.fromResource).toList();

  Future<Operation> createOperation(
    String serviceId, {
    String? scheduleId,
    String? name,
    String? details,
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.operations,
      one: {
        'service': Identifier(ResourceType.services, serviceId),
        if (scheduleId != null) 'schedule': Identifier(ResourceType.schedules, scheduleId),
      },
      attributes: {'name': ?name, 'details': ?details},
    );
    return Operation.fromResource(response.resource);
  }

  Future<Operation?> updateOperation(
    String operationId, {
    String? scheduleId,
    String? name,
    String? details,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.operations,
      operationId,
      one: {'schedule': scheduleId == null ? null : Identifier(ResourceType.schedules, scheduleId)},
      attributes: {'name': ?name, 'details': ?details},
    );
    final updated = response.resource;
    return updated == null ? null : Operation.fromResource(updated);
  }

  Future<void> deleteOperation(String operationId) async {
    await _jsonApi.deleteResource(ResourceType.operations, operationId);
  }

  // State

  String saveState() => _token ?? '';

  void restoreState(String token) {
    if (token.isEmpty) throw ArgumentError('Empty token');
    _token = token;
  }

  Handler _authenticated(Handler inner) => (request) {
    final token = _token;
    if (token != null) {
      request.headers['Authorization'] = ['Bearer $token'];
    }
    return inner(request);
  };

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}

class InvalidResponse(final String message) implements Exception;
