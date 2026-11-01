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

  Future<Resource> createVehicle({
    required String name,
    required DateTime manufactureDate,
    String distanceUnit = 'mi',
  }) async {
    final response = await _jsonApi.createNew(
      ResourceType.vehicles,
      attributes: {
        'name': name,
        'manufacture_date': _date(manufactureDate),
        'distance_unit': distanceUnit,
      },
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

class Session(final String id, {final Uri? completionUri}) {
  static Session fromResource(Resource resource) {
    final redirect = resource.attributes['redirect'];
    final completionUri = redirect is String ? Uri.parse(redirect) : null;
    return Session(resource.id, completionUri: completionUri);
  }
}

class InvalidResponse(final String message) implements Exception;

class _State(final String id, final String token);
