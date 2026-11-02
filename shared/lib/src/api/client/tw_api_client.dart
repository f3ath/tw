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
  _State? _state;

  // Sessions

  Future<Session> createSession() async {
    final response = await _jsonApi.createNew(ResourceType.sessions);
    final resource = response.resource;
    final token = resource.attributes['token'];
    if (token is! String) {
      throw InvalidResponse('Missing session token');
    }
    _state = _State(resource.id, token);
    return Session.fromResource(resource);
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection(ResourceType.sessions)).collection;

  Future<Session> fetchSession(String id) async {
    final r = await _jsonApi.fetchResource(ResourceType.sessions, id);
    return Session.fromResource(r.resource);
  }

  Future<Session> fetchCurrentSession() async {
    final state = _state;
    if (state == null) {
      throw StateError('Unauthenticated');
    }
    return fetchSession(state.id);
  }

  // Users

  Future<User?> fetchCurrentUser() async {
    final state = _state;
    if (state == null) {
      throw StateError('Unauthenticated');
    }
    final resource = (await _jsonApi.fetchRelatedResource(
      ResourceType.sessions,
      state.id,
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
    String vehicleId,
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
      one: {'vehicle': Identifier(ResourceType.vehicles, vehicleId)},
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
    final state = _state;
    if (state == null) {
      throw StateError('Unauthenticated');
    }
    await deleteSessionById(state.id);
  }

  Future<void> deleteSessionById(String id) async {
    await _jsonApi.deleteResource(ResourceType.sessions, id);
    if (_state?.id == id) {
      _state = null;
    }
  }

  String saveState() {
    final state = _state;
    if (state == null) {
      return '';
    }
    return '${state.id}:${state.token}';
  }

  void restoreState(String state) {
    if (state.split(':') case [final id, final token]) {
      _state = _State(id, token);
    } else if (state.isEmpty) {
      _state = null;
    } else {
      throw ArgumentError('Invalid state');
    }
  }

  Handler _authenticated(Handler inner) => (request) {
    final state = _state;
    if (state != null) {
      request.headers['Authorization'] = ['Bearer ${state.token}'];
    }
    return inner(request);
  };

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}

class InvalidResponse(final String message) implements Exception;

class _State(final String id, final String token);
