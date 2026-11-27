import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/query.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/db/duplicate_id.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/schedules/schedule_resource.dart';
import 'package:server/src/schedules/schedules_dao.dart';
import 'package:server/src/services/operations_dao.dart';
import 'package:server/src/services/service_resource.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:server/src/validation/date.dart';
import 'package:server/src/vehicles/vehicle_resource.dart';
import 'package:server/src/vehicles/vehicles_dao.dart';
import 'package:shared/api.dart' show MileageUnit;
import 'package:shared/resource_id.dart';
import 'package:shared/time.dart';

class VehiclesController(
  final VehiclesTDAOProvider _ownedVehicles,
  final SchedulesTDAOProvider _ownedSchedules,
  final ServicesTDAOProvider _ownedServices,
  final OperationsDAOProvider _ownedOperations,
  final UriBuilder _uriFor, {
  final Now _now = DateTime.now,
}) extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final vehicles = await _ownedVehicles(request.userId).fetchAll();
    return ok(OutboundDataDocument.collection(vehicles.map(VehicleResource.new)));
  }

  @override
  Future<Response> createResource(Request request, Target target, NewResource newResource) async {
    final resource = newResource.toResource(ResourceId.generate);
    final attributes = resource.attributes;
    final name = _parseName(attributes['name']);
    final manufactureDate = parseDate(attributes['manufacture_date'], now: _now);
    if (name == null) {
      return badRequest(OutboundErrorDocument([ErrorObject(title: 'Empty name')]));
    }
    if (manufactureDate == null) {
      return badRequest(OutboundErrorDocument([ErrorObject(title: 'Invalid date')]));
    }
    final mileageUnit = resource.attributes.containsKey('mileage_unit')
        ? resource.attributes['mileage_unit']
        : MileageUnit.mi.name;
    if (mileageUnit is! String || !MileageUnit.values.asNameMap().containsKey(mileageUnit)) {
      return badRequest();
    }
    final VehicleRecord vehicle;
    try {
      vehicle = await _ownedVehicles(request.userId).create(
        id: resource.id,
        mileageUnit: MileageUnit.values.byName(mileageUnit),
        name: name,
        manufactureDate: manufactureDate,
      );
    } on DuplicateId {
      return conflict();
    }
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
    final unit = attributes['mileage_unit'];
    if (attributes.containsKey('mileage_unit') &&
        (unit is! String || !MileageUnit.values.asNameMap().containsKey(unit))) {
      return badRequest();
    }
    final mileageUnit = unit is String ? MileageUnit.values.byName(unit) : null;
    final name = _parseName(attributes['name']);
    final manufactureDate = parseDate(attributes['manufacture_date'], now: _now);
    if ((attributes.containsKey('name') && name == null) ||
        (attributes.containsKey('manufacture_date') && manufactureDate == null)) {
      return badRequest();
    }
    final VehicleRecord? vehicle;
    try {
      vehicle = await _ownedVehicles(request.userId).update(
        id: target.id,
        name: name,
        manufactureDate: manufactureDate,
        mileageUnit: mileageUnit,
      );
    } on InvalidRecord {
      return badRequest();
    }
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
  Future<Response> fetchRelated(Request request, RelatedTarget target) async =>
      switch (target.relationship) {
        'schedule' => _fetchSchedules(request, target.id),
        'service' => _fetchServices(request, target.id),
        _ => notFound(),
      };

  Future<Response> _fetchSchedules(Request request, String vehicleId) async {
    if (Include.fromUri(request.uri).isNotEmpty) return badRequest();
    final userId = request.userId;
    final vehicle = await _ownedVehicles(userId).fetchById(id: vehicleId);
    if (vehicle == null) return notFound();

    final schedules = await _ownedSchedules(userId).fetchByVehicleId(vehicleId: vehicleId);
    return ok(ScheduleResource.vehicleCollection(schedules, vehicle.manufactureDate));
  }

  Future<Response> _fetchServices(Request request, String vehicleId) async {
    final include = Include.fromUri(request.uri);
    final emptyInclude = include.length == 1 && include.single.isEmpty;
    if (!emptyInclude && include.any((path) => path != 'operations')) return badRequest();

    final userId = request.userId;
    if (!await _ownedVehicles(userId).existsById(id: vehicleId)) return notFound();

    final services = await _ownedServices(userId).fetchByVehicleId(vehicleId: vehicleId);
    if (include.isEmpty) {
      return ok(OutboundDataDocument.collection(services.map(ServiceResource.new)));
    }
    final operations = emptyInclude
        ? null
        : await _ownedOperations(userId)
              .fetchByServiceIds(services.map((service) => service.id).toList());
    return ok(ServicesWithOperationsDocument(services, operations));
  }

  static String? _parseName(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}
