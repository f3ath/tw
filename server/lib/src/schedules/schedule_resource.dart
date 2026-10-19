import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:server/src/schedules/schedules_tdao.dart';

class ScheduleResource(ScheduleRecord record) extends Resource {
  this : super(ResourceType.schedules, record.id) {
    attributes.addAll({
      'name': record.name,
      'interval_miles': record.intervalMiles,
      'interval_months': record.intervalMonths,
      'details': record.details,
    });
    relationships['vehicle'] = ToOne(Identifier(ResourceType.vehicles, record.vehicleId));
  }
}
