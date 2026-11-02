import 'package:http_interop/http_interop.dart';
import 'package:json_api/document.dart';
import 'package:json_api/routing.dart';
import 'package:json_api/server.dart';
import 'package:server/src/auth/request_ext.dart';
import 'package:server/src/db/invalid_record.dart';
import 'package:server/src/json_api/base_controller.dart';
import 'package:server/src/services/operation_resource.dart';
import 'package:server/src/services/operations_dao.dart';
import 'package:shared/api.dart';
import 'package:uuid/uuid.dart';

class OperationsController(final OperationsDAOProvider _ownedOperations, final UriBuilder _uriFor)
    extends BaseController {
  static const _uuid = Uuid();

  @override
  Future<Response> createResource(
    Request request,
    CollectionTarget target,
    NewResource newResource,
  ) async {
    final service = newResource.relationships['service'];
    if (service == null ||
        service.length != 1 ||
        service.single.id == null ||
        service.single.type != ResourceType.services) {
      return badRequest();
    }
    final schedule = newResource.relationships['schedule'];
    if (schedule != null &&
        (schedule.length > 1 ||
            schedule.isNotEmpty &&
                (schedule.single.id == null || schedule.single.type != ResourceType.schedules))) {
      return badRequest();
    }
    final scheduleId = schedule?.singleOrNull?.id;
    final attributes = newResource.attributes;
    if (!_isValid(attributes, scheduleId)) return badRequest();
    final OperationRecord? operation;
    try {
      operation = await _ownedOperations(request.userId).create(
        id: _uuid.v4(),
        serviceId: service.single.id!,
        scheduleId: scheduleId,
        name: attributes['name'] as String?,
        details: attributes['details'] as String?,
      );
    } on InvalidRecord {
      return badRequest();
    }
    if (operation == null) return notFound();
    return created(
      OutboundDataDocument.resource(OperationResource(operation)),
      _uriFor(ResourceTarget(target.type, operation.id)).toString(),
    );
  }

  @override
  Future<Response> updateResource(Request request, ResourceTarget target, Resource resource) async {
    if (resource.relationships.containsKey('service')) return badRequest();
    final schedule = resource.one('schedule');
    if (schedule?.isNotEmpty == true && schedule!.single.type != ResourceType.schedules) {
      return badRequest();
    }
    final scheduleId = schedule?.singleOrNull?.id;
    final attributes = resource.attributes;
    if (!_isValid(attributes, scheduleId)) return badRequest();
    final OperationRecord? operation;
    try {
      operation = await _ownedOperations(request.userId).update(
        id: target.id,
        scheduleId: scheduleId,
        name: attributes['name'] as String?,
        details: attributes['details'] as String?,
      );
    } on InvalidRecord {
      return badRequest();
    }
    if (operation == null) return notFound();
    return ok(OutboundDataDocument.resource(OperationResource(operation)));
  }

  @override
  Future<Response> fetchResource(Request request, ResourceTarget target) async {
    final operation = await _ownedOperations(request.userId).fetchById(target.id);
    return operation == null
        ? notFound()
        : ok(OutboundDataDocument.resource(OperationResource(operation)));
  }

  @override
  Future<Response> deleteResource(Request request, ResourceTarget target) async =>
      await _ownedOperations(request.userId).delete(target.id) ? noContent() : notFound();

  static bool _isValid(Map<String, dynamic> attributes, String? scheduleId) {
    if (scheduleId != null) {
      return !attributes.containsKey('name') && !attributes.containsKey('details');
    }
    final name = attributes['name'];
    final details = attributes['details'];
    return name is String && name.trim().isNotEmpty && (details == null || details is String);
  }
}
