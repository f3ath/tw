import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/request_ext.dart';
import 'package:tw_server/src/json_api/base_controller.dart';
import 'package:tw_server/src/schedules/schedule_resource.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';
import 'package:tw_server/src/vehicles/vehicle_resource.dart';
import 'package:tw_server/src/vehicles/vehicles_dao.dart';
import 'package:uuid/uuid.dart';

class VehiclesController(
  final VehiclesDAO _vehiclesDAO,
  final SchedulesDAO _schedulesDAO,
  final UriBuilder _uriFor,
) extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final vehicles = await _vehiclesDAO.fetchByUserId(request.userId);
    return ok(OutboundDataDocument.collection(vehicles.map(VehicleResource.new)));
  }

  @override
  Future<Response> createResource(Request request, Target target, NewResource newResource) async {
    final resource = newResource;
    final vehicle = await _vehiclesDAO.create(
      id: _uuid.v4(),
      name: resource.attributes['name'] as String,
      userId: request.userId,
      manufactureDate: DateTime.parse(resource.attributes['manufacture_date'] as String),
    );
    return created(
      OutboundDataDocument.resource(VehicleResource(vehicle)),
      _uriFor(ResourceTarget(target.type, vehicle.id)).toString(),
    );
  }

  @override
  Future<Response> fetchResource(Request request, ResourceTarget target) async {
    final vehicle = await _vehiclesDAO.fetchByIdAndUserId(id: target.id, userId: request.userId);
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(VehicleResource(vehicle)));
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    final manufactureDate = resource.attributes.containsKey('manufacture_date')
        ? DateTime.parse(resource.attributes['manufacture_date'] as String)
        : null;
    final vehicle = await _vehiclesDAO.update(
      id: target.id,
      userId: request.userId,
      name: resource.attributes['name'] as String?,
      manufactureDate: manufactureDate,
    );
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(VehicleResource(vehicle)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _vehiclesDAO.delete(id: target.id, userId: request.userId)) {
      return notFound();
    }
    return noContent();
  }

  @override
  Future<Response> fetchRelated(Request request, RelatedTarget target) async {
    if (target.relationship != 'schedule') return notFound();

    final schedules = await _schedulesDAO.fetchByVehicleIdAndUserId(
      vehicleId: target.id,
      userId: request.userId,
    );
    if (schedules == null) return notFound();

    return ok(OutboundDataDocument.collection(schedules.map(ScheduleResource.new)));
  }
}
