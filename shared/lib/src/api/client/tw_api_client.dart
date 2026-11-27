import 'package:http_interop/http_interop.dart';
import 'package:json_api/client.dart';
import 'package:json_api/document.dart';
import 'package:json_api/query.dart';
import 'package:json_api/routing.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';

class TwApiClient(UriDesign urlDesign, Handler handler) {
  this {
    _jsonApi = RoutingClient(urlDesign.uri, Client(_authenticated(handler)));
  }

  late final RoutingClient _jsonApi;

  /// Auth token
  String? token;

  // Sessions

  Future<Session> createSession() async {
    final response = await _jsonApi.createNew(ResourceType.sessions);
    final resource = response.resource;
    final token = resource.attributes['token'];
    if (token is! String) {
      throw InvalidResponse('Missing session token');
    }
    this.token = token;
    return resource.toSession();
  }

  Future<List<Resource>> listSessions() async =>
      (await _jsonApi.fetchCollection(ResourceType.sessions)).collection;

  Future<Session> fetchSession(String id) async {
    final r = await _jsonApi.fetchResource(ResourceType.sessions, id);
    return r.resource.toSession();
  }

  Future<Session> fetchCurrentSession() async {
    if (token == null) {
      throw StateError('Unauthenticated');
    }
    return fetchSession('current');
  }

  Future<void> deleteCurrentSession() async {
    if (token == null) {
      throw StateError('Unauthenticated');
    }
    try {
      await _jsonApi.deleteResource(ResourceType.sessions, 'current');
    } finally {
      token = null;
    }
  }

  Future<void> deleteSessionById(String id) async =>
      await _jsonApi.deleteResource(ResourceType.sessions, id);

  // Users

  Future<User?> fetchCurrentUser() async {
    if (token == null) {
      throw StateError('Unauthenticated');
    }
    final resource = (await _jsonApi.fetchRelatedResource(
      ResourceType.sessions,
      'current',
      'user',
    )).resource;
    return resource?.toUser();
  }

  // Vehicles

  Future<Vehicle> createVehicle({
    String? id,
    required String name,
    required CalendarDate manufactureDate,
    MileageUnit mileageUnit = MileageUnit.mi,
  }) async {
    final attributes = {
      'name': name,
      'manufacture_date': manufactureDate.toIsoDateString(),
      'mileage_unit': mileageUnit.name,
    };
    final resource = id == null
        ? (await _jsonApi.createNew(ResourceType.vehicles, attributes: attributes)).resource
        : (await _jsonApi.create(ResourceType.vehicles, id, attributes: attributes)).resource;
    if (resource == null) {
      throw InvalidResponse('Missing created vehicle');
    }
    return resource.toVehicle();
  }

  Future<List<Vehicle>> listVehicles() async =>
      (await _jsonApi.fetchCollection(ResourceType.vehicles)).collection
          .map((it) => it.toVehicle())
          .toList();

  Future<Vehicle> fetchVehicle(String id) async =>
      (await _jsonApi.fetchResource(ResourceType.vehicles, id)).resource.toVehicle();

  Future<Vehicle?> updateVehicle(
    String id, {
    String? name,
    CalendarDate? manufactureDate,
    MileageUnit? mileageUnit,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.vehicles,
      id,
      attributes: {
        'name': ?name,
        'mileage_unit': ?mileageUnit?.name,
        if (manufactureDate != null) 'manufacture_date': manufactureDate.toIsoDateString(),
      },
    );
    return response.resource?.toVehicle();
  }

  Future<void> deleteVehicle(String id) async {
    await _jsonApi.deleteResource(ResourceType.vehicles, id);
  }

  // Schedules

  Future<List<Schedule>> listSchedules(String vehicleId) async {
    final response = await _jsonApi.fetchRelatedCollection(
      ResourceType.vehicles,
      vehicleId,
      'schedule',
    );
    return response.collection
        .map((resource) => resource.toSchedule(included: response.included))
        .toList();
  }

  Future<Schedule> createSchedule(
    String vehicleId, {
    String? id,
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  }) async {
    final one = {'vehicle': Identifier(ResourceType.vehicles, vehicleId)};
    final attributes = {
      'name': name,
      'interval_distance': intervalDistance,
      'interval_months': intervalMonths,
      'details': details,
    };
    if (id != null) {
      final response = await _jsonApi.create(
        ResourceType.schedules,
        id,
        one: one,
        attributes: attributes,
      );
      final resource = response.resource;
      if (resource == null) {
        throw InvalidResponse('Missing created schedule');
      }
      return resource.toSchedule();
    }
    final response = await _jsonApi.createNew(
      ResourceType.schedules,
      one: one,
      attributes: attributes,
    );
    return response.resource.toSchedule();
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
    return response.resource?.toSchedule();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _jsonApi.deleteResource(ResourceType.schedules, scheduleId);
  }

  // Services

  Future<List<Service>> listServices(String vehicleId, {bool includeOperations = false}) async {
    final response = await _jsonApi.fetchRelatedCollection(
      ResourceType.vehicles,
      vehicleId,
      'service',
      query: [
        if (includeOperations) Include(['operations']),
      ],
    );
    final operationsById = {
      for (final resource in response.included)
        if (resource.type == ResourceType.operations) resource.id: resource.toOperation(),
    };
    return response.collection.map((resource) {
      final operations = resource.many('operations') ?? const <Identifier>[];
      return resource.toService(
        operations: List.unmodifiable(
          operations
              .where((identifier) => identifier.type == ResourceType.operations)
              .map((identifier) => operationsById[identifier.id])
              .whereType<Operation>(),
        ),
      );
    }).toList();
  }

  Future<Service> createService(
    String vehicleId, {
    String? id,
    required CalendarDate date,
    required int odometer,
    String details = '',
  }) async {
    final one = {'vehicle': Identifier(ResourceType.vehicles, vehicleId)};
    final attributes = {'date': date.toIsoDateString(), 'odometer': odometer, 'details': details};
    final resource = id == null
        ? (await _jsonApi.createNew(
            ResourceType.services,
            one: one,
            attributes: attributes,
          )).resource
        : (await _jsonApi.create(
            ResourceType.services,
            id,
            one: one,
            attributes: attributes,
          )).resource;
    if (resource == null) {
      throw InvalidResponse('Missing created service');
    }
    return resource.toService();
  }

  Future<Service?> updateService(
    String serviceId, {
    required CalendarDate date,
    required int odometer,
    String? details,
  }) async {
    final response = await _jsonApi.updateResource(
      ResourceType.services,
      serviceId,
      attributes: {'date': date.toIsoDateString(), 'odometer': odometer, 'details': ?details},
    );
    return response.resource?.toService();
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
      )).collection.map((it) => it.toOperation()).toList();

  Future<Operation> createOperation(
    String serviceId, {
    String? id,
    String? scheduleId,
    String? name,
    String? details,
  }) async {
    final one = {
      'service': Identifier(ResourceType.services, serviceId),
      if (scheduleId != null) 'schedule': Identifier(ResourceType.schedules, scheduleId),
    };
    final attributes = {'name': ?name, 'details': ?details};
    final resource = id == null
        ? (await _jsonApi.createNew(
            ResourceType.operations,
            one: one,
            attributes: attributes,
          )).resource
        : (await _jsonApi.create(
            ResourceType.operations,
            id,
            one: one,
            attributes: attributes,
          )).resource;
    if (resource == null) {
      throw InvalidResponse('Missing created operation');
    }
    return resource.toOperation();
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
    return response.resource?.toOperation();
  }

  Future<void> deleteOperation(String operationId) async {
    await _jsonApi.deleteResource(ResourceType.operations, operationId);
  }

  Handler _authenticated(Handler inner) => (request) {
    final t = token;
    if (t != null) {
      request.headers['Authorization'] = ['Bearer $t'];
    }
    return inner(request);
  };
}

class InvalidResponse(final String message) implements Exception;
