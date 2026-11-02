import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/schedules/schedule_resource.dart';
import 'package:server/src/schedules/schedules_dao.dart';
import 'package:server/src/services/service_resource.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:server/src/vehicles/vehicle_resource.dart';
import 'package:server/src/vehicles/vehicles_dao.dart';
import 'package:shared/time.dart';
import 'package:shared/api.dart' show DistanceUnit;
import 'package:uuid/uuid.dart';

class VehiclesController(
  final VehiclesTDAOProvider _ownedVehicles,
  final SchedulesTDAOProvider _ownedSchedules,
  final ServicesTDAOProvider _ownedServices,
  final UriBuilder _uriFor, {
  final Clock _clock = systemClock,
}) extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final vehicles = await _ownedVehicles(request.userId).fetchAll();
    return ok(OutboundDataDocument.collection(vehicles.map(VehicleResource.new)));
  }

  @override
  Future<Response> createResource(Request request, Target target, NewResource newResource) async {
    final attributes = newResource.attributes;
    final name = _parseName(attributes['name']);
    final manufactureDate = _parseManufactureDate(attributes['manufacture_date']);
    if (name == null || manufactureDate == null) return badRequest();
    final distanceUnit = newResource.attributes.containsKey('distance_unit')
        ? newResource.attributes['distance_unit']
        : DistanceUnit.mi.name;
    if (distanceUnit is! String || !DistanceUnit.values.asNameMap().containsKey(distanceUnit)) {
      return badRequest();
    }
    final vehicle = await _ownedVehicles(request.userId).create(
      id: _uuid.v4(),
      distanceUnit: DistanceUnit.values.byName(distanceUnit),
      name: name,
      manufactureDate: manufactureDate,
    );
    return created(
      OutboundDataDocument.resource(VehicleResource(vehicle)),
      _uriFor(ResourceTarget(target.type, vehicle.id)).toString(),
    );
  }

  @override
  Future<Response> fetchResource(Request request, ResourceTarget target) async {
    final vehicle = await _ownedVehicles(request.userId).fetchById(id: target.id);
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(VehicleResource(vehicle)));
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    final attributes = resource.attributes;
    if (attributes.containsKey('distance_unit')) return badRequest();
    final name = _parseName(attributes['name']);
    final manufactureDate = _parseManufactureDate(attributes['manufacture_date']);
    if ((attributes.containsKey('name') && name == null) ||
        (attributes.containsKey('manufacture_date') && manufactureDate == null)) {
      return badRequest();
    }
    final vehicle = await _ownedVehicles(request.userId)
        .update(id: target.id, name: name, manufactureDate: manufactureDate);
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(VehicleResource(vehicle)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _ownedVehicles(request.userId).delete(id: target.id)) {
      return notFound();
    }
    return noContent();
  }

  @override
  Future<Response> fetchRelated(Request request, RelatedTarget target) async {
    if (target.relationship != 'schedule' && target.relationship != 'service') return notFound();

    final vehicle = await _ownedVehicles(request.userId).fetchById(id: target.id);
    if (vehicle == null) return notFound();

    if (target.relationship == 'service') {
      final services = await _ownedServices(request.userId).fetchByVehicleId(vehicleId: target.id);
      return ok(OutboundDataDocument.collection(services.map(ServiceResource.new)));
    }

    final schedules = await _ownedSchedules(request.userId).fetchByVehicleId(vehicleId: target.id);
    return ok(OutboundDataDocument.collection(schedules.map(ScheduleResource.new)));
  }

  static String? _parseName(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  DateTime? _parseManufactureDate(Object? value) {
    if (value is! String) return null;
    final date = DateTime.tryParse(value);
    if (date == null || date.toIso8601String().split('T').first != value) return null;
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    return date.isAfter(today) ? null : date;
  }
}
