import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:tw_server/src/http/context.dart';
import 'package:tw_server/src/json_api/request_ext.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';

class SchedulesController(final SchedulesDAO _schedulesDAO) extends BaseController {
  @override
  Future<Response> fetchCollection(Request request, Target target) async {
    final vehicleId = request.uri.queryParameters['vehicle_id'];
    if (vehicleId == null) return notFound();

    final schedules = await _schedulesDAO.fetchByVehicleIdAndUserId(
      vehicleId: vehicleId,
      userId: Context(request).userId,
    );
    if (schedules == null) return notFound();

    return ok(OutboundDataDocument.collection(schedules.map((it) => _resource(target, it))));
  }

  @override
  Future<Response> createResource(Request request, Target target) async {
    final resource = await request.document().then((it) => it.dataAsNewResource());
    final attributes = resource.attributes;
    final schedule = await _schedulesDAO.create(
      vehicleId: attributes['vehicle_id'] as String,
      userId: Context(request).userId,
      name: attributes['name'] as String,
      intervalMiles: attributes['interval_miles'] as int,
      intervalMonths: attributes['interval_months'] as int,
      details: attributes['details'] as String,
    );
    if (schedule == null) return notFound();

    return created(
      OutboundDataDocument.resource(_resource(target, schedule)),
      '/${target.type}/${schedule.id}',
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target) async {
    final resource = await request.resource();
    final attributes = resource.attributes;
    final schedule = await _schedulesDAO.update(
      id: target.id,
      vehicleId: attributes['vehicle_id'] as String,
      userId: Context(request).userId,
      name: attributes['name'] as String?,
      intervalMiles: attributes['interval_miles'] as int?,
      intervalMonths: attributes['interval_months'] as int?,
      details: attributes['details'] as String?,
    );
    if (schedule == null) return notFound();

    return ok(OutboundDataDocument.resource(_resource(target, schedule)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async {
    if (!await _schedulesDAO.delete(id: target.id, userId: Context(request).userId)) {
      return notFound();
    }
    return noContent();
  }

  Resource _resource(Target target, ScheduleRecord schedule) => Resource(target.type, schedule.id)
    ..attributes.addAll({
      'name': schedule.name,
      'interval_miles': schedule.intervalMiles,
      'interval_months': schedule.intervalMonths,
      'details': schedule.details,
    });
}
