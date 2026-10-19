import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/schedules/schedule_resource.dart';
import 'package:server/src/schedules/schedules_tdao.dart';
import 'package:uuid/uuid.dart';

class SchedulesController(final SchedulesTDAOProvider _ownedSchedules, final UriBuilder _uriFor)
    extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> fetchCollection(Request request, CollectionTarget target) async {
    final all = await _ownedSchedules(request.userId).fetchAll();
    return ok(OutboundDataDocument.collection(all.map(ScheduleResource.new)));
  }

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final attributes = newResource.attributes;
    final vehicle = newResource.relationships['vehicle']!;
    final schedule = await _ownedSchedules(request.userId).create(
      id: _uuid.v4(),
      vehicleId: vehicle.single.id!,
      name: attributes['name'] as String,
      intervalMiles: attributes['interval_miles'] as int,
      intervalMonths: attributes['interval_months'] as int,
      details: attributes['details'] as String,
    );
    if (schedule == null) return notFound();

    return created(
      OutboundDataDocument.resource(ScheduleResource(schedule)),
      _uriFor(ResourceTarget(target.type, schedule.id)).toString(),
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    final attributes = resource.attributes;
    final vehicle = resource.one('vehicle');
    final schedule = await _ownedSchedules(request.userId).update(
      id: target.id,
      vehicleId: vehicle!.single.id,
      name: attributes['name'] as String?,
      intervalMiles: attributes['interval_miles'] as int?,
      intervalMonths: attributes['interval_months'] as int?,
      details: attributes['details'] as String?,
    );
    if (schedule == null) return notFound();

    return ok(OutboundDataDocument.resource(ScheduleResource(schedule)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _ownedSchedules(request.userId).delete(id: target.id)) {
      return notFound();
    }
    return noContent();
  }
}
