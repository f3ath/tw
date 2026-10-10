import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/http/context.dart';
import 'package:tw_server/src/json_api/request_ext.dart';
import 'package:tw_server/src/vehicles/vehicles_dao.dart';

class VehiclesController(final VehiclesDAO _vehiclesDAO) extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final userId = Context(request).userId;
    final vehicles = await _vehiclesDAO.fetchByUserId(userId);
    return ok(OutboundDataDocument.collection(vehicles.map((it) => _resource(target, it))));
  }

  @override
  Future<Response> createResource(Request request, Target target) async {
    final userId = Context(request).userId;
    final resource = await request.document().then((it) => it.dataAsNewResource());
    final vehicle = await _vehiclesDAO.create(
      name: resource.attributes['name'] as String,
      userId: userId,
      manufactureDate: DateTime.parse(resource.attributes['manufacture_date'] as String),
    );
    return created(
      OutboundDataDocument.resource(_resource(target, vehicle)),
      '/${target.type}/${vehicle.id}',
    );
  }

  @override
  Future<Response> fetchResource(Request request, ResourceTarget target) async {
    final userId = Context(request).userId;
    final vehicle = await _vehiclesDAO.fetchByIdAndUserId(id: target.id, userId: userId);
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(_resource(target, vehicle)));
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target) async {
    final userId = Context(request).userId;
    final resource = await request.resource();
    final manufactureDate = resource.attributes.containsKey('manufacture_date')
        ? DateTime.parse(resource.attributes['manufacture_date'] as String)
        : null;
    final vehicle = await _vehiclesDAO.update(
      id: target.id,
      userId: userId,
      name: resource.attributes['name'] as String?,
      manufactureDate: manufactureDate,
    );
    if (vehicle == null) {
      return notFound();
    }
    return ok(OutboundDataDocument.resource(_resource(target, vehicle)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    final userId = Context(request).userId;
    if (!await _vehiclesDAO.delete(id: target.id, userId: userId)) {
      return notFound();
    }
    return noContent();
  }

  Resource _resource(Target target, VehicleRecord vehicle) => Resource(target.type, vehicle.id)
    ..attributes['name'] = vehicle.name
    ..attributes['manufacture_date'] = vehicle.manufactureDate.toIso8601String().split('T').first;
}
