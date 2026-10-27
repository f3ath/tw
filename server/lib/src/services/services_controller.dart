import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/services/service_resource.dart';
import 'package:server/src/services/services_tdao.dart';
import 'package:uuid/uuid.dart';

class ServicesController(final ServicesTDAOProvider _ownedServices, final UriBuilder _uriFor)
    extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final attributes = newResource.attributes;
    if (attributes['date'] is! String || attributes['mileage'] is! int) return badRequest();
    final vehicle = newResource.relationships['vehicle']!;
    final service = await _ownedServices(request.userId).create(
      id: _uuid.v4(),
      vehicleId: vehicle.single.id!,
      date: DateTime.parse(attributes['date'] as String),
      mileage: attributes['mileage'] as int,
      details: attributes['details'] as String? ?? '',
    );
    if (service == null) return notFound();

    return created(
      OutboundDataDocument.resource(ServiceResource(service)),
      _uriFor(ResourceTarget(target.type, service.id)).toString(),
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    final attributes = resource.attributes;
    final vehicle = resource.one('vehicle');
    if (attributes['date'] is! String || attributes['mileage'] is! int) return badRequest();
    final service = await _ownedServices(request.userId).update(
      id: target.id,
      vehicleId: vehicle!.single.id,
      date: DateTime.parse(attributes['date'] as String),
      mileage: attributes['mileage'] as int,
      details: attributes['details'] as String?,
    );
    if (service == null) return notFound();

    return ok(OutboundDataDocument.resource(ServiceResource(service)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _ownedServices(request.userId).delete(id: target.id)) {
      return notFound();
    }
    return noContent();
  }
}
