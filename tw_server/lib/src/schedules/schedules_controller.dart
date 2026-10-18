import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/auth/request_ext.dart';
import 'package:tw_server/src/json_api/base_controller.dart';
import 'package:tw_server/src/schedules/schedule_resource.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';
import 'package:uuid/uuid.dart';

class SchedulesController(final SchedulesDAO _schedulesDAO, final UriBuilder _uriFor)
    extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> fetchCollection(Request request, CollectionTarget target) async => ok(
    OutboundDataDocument.collection(
      (await _schedulesDAO.fetchByUserId(request.userId)).map(ScheduleResource.new),
    ),
  );

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final resource = newResource;
    final attributes = resource.attributes;
    final vehicle = resource.relationships['vehicle']!;
    final schedule = await _schedulesDAO.create(
      id: _uuid.v4(),
      vehicleId: vehicle.single.id!,
      userId: request.userId,
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
    final schedule = await _schedulesDAO.update(
      id: target.id,
      vehicleId: vehicle!.single.id,
      userId: request.userId,
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
    if (!await _schedulesDAO.delete(id: target.id, userId: request.userId)) {
      return notFound();
    }
    return noContent();
  }
}
