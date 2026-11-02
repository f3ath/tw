import 'package:json_api/document.dart';
import 'package:server/src/services/operations_dao.dart';
import 'package:shared/api.dart';

class OperationResource(OperationRecord record) extends Resource {
  this : super(ResourceType.operations, record.id) {
    attributes.addAll({'name': record.name, 'details': record.details});
    relationships.addAll({
      'service': ToOne(Identifier(ResourceType.services, record.serviceId)),
      'schedule': ToOne(
        record.scheduleId == null ? null : Identifier(ResourceType.schedules, record.scheduleId!),
      ),
    });
  }
}
