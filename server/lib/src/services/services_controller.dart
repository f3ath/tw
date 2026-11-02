import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/services/service_resource.dart';
import 'package:server/src/services/services_dao.dart';
import 'package:server/src/validation/date.dart';
import 'package:shared/time.dart';
import 'package:uuid/uuid.dart';

class ServicesController(
  final ServicesTDAOProvider _ownedServices,
  final UriBuilder _uriFor, {
  final Clock _clock = systemClock,
}) extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final input = _parseInput(newResource.attributes);
    if (input == null) return badRequest();
    final vehicle = newResource.relationships['vehicle'];
    if (vehicle == null || vehicle.length != 1 || vehicle.single.id == null) return badRequest();
    final ServiceRecord? service;
    try {
      service = await _ownedServices(request.userId).create(
        id: _uuid.v4(),
        vehicleId: vehicle.single.id!,
        date: input.date,
        odometer: input.odometer,
        details: input.details ?? '',
      );
    } on InvalidRecord {
      return badRequest();
    }
    if (service == null) return notFound();

    return created(
      OutboundDataDocument.resource(ServiceResource(service)),
      _uriFor(ResourceTarget(target.type, service.id)).toString(),
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    final input = _parseInput(resource.attributes);
    if (input == null) return badRequest();
    final vehicle = resource.one('vehicle');
    if (vehicle == null || vehicle.isEmpty) return badRequest();
    final ServiceRecord? service;
    try {
      service = await _ownedServices(request.userId).update(
        id: target.id,
        vehicleId: vehicle.single.id,
        date: input.date,
        odometer: input.odometer,
        details: input.details,
      );
    } on InvalidRecord {
      return badRequest();
    }
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

  ({DateTime date, int odometer, String? details})? _parseInput(Map<String, dynamic> attributes) {
    final date = parseDate(attributes['date'], clock: _clock, maxDaysInFuture: 7);
    final odometer = attributes['odometer'];
    final details = attributes['details'];
    if (date == null || odometer is! int || odometer < 0 || details != null && details is! String) {
      return null;
    }
    return (date: date, odometer: odometer, details: details as String?);
  }
}
