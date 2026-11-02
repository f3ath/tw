import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/schedules/schedule_resource.dart';
import 'package:server/src/schedules/schedules_dao.dart';
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
    final attributes = {'details': '', 'is_archived': false, ...newResource.attributes};
    if (!_isValid(attributes)) return badRequest();
    final vehicle = newResource.relationships['vehicle'];
    if (vehicle == null || vehicle.length != 1 || vehicle.single.id == null) {
      return badRequest();
    }
    final schedule = await _ownedSchedules(request.userId).create(
      id: _uuid.v4(),
      vehicleId: vehicle.single.id!,
      name: attributes['name'] as String,
      intervalDistance: attributes['interval_distance'] as int?,
      intervalMonths: attributes['interval_months'] as int?,
      details: attributes['details'] as String,
      isArchived: attributes['is_archived'] as bool,
    );
    if (schedule == null) return notFound();

    return created(
      OutboundDataDocument.resource(ScheduleResource(schedule)),
      _uriFor(ResourceTarget(target.type, schedule.id)).toString(),
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    if (resource.relationships.containsKey('vehicle')) return badRequest();
    final dao = _ownedSchedules(request.userId);
    final existing = await dao.fetchById(id: target.id);
    if (existing == null) return notFound();
    final attributes = {...existing.toMap(), ...resource.attributes};
    if (!_isValid(attributes)) return badRequest();
    final schedule = await dao.update(
      id: target.id,
      name: attributes['name'] as String,
      intervalDistance: attributes['interval_distance'] as int?,
      intervalMonths: attributes['interval_months'] as int?,
      details: attributes['details'] as String,
      isArchived: attributes['is_archived'] as bool,
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

  static bool _isValid(Map<String, dynamic> attributes) {
    final name = attributes['name'];
    final distance = attributes['interval_distance'];
    final months = attributes['interval_months'];
    return name is String &&
        name.trim().isNotEmpty &&
        (distance == null || distance is int && distance > 0) &&
        (months == null || months is int && months > 0) &&
        (distance != null || months != null) &&
        attributes['details'] is String &&
        attributes['is_archived'] is bool;
  }
}
