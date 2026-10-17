import 'package:json_api/document.dart';
import 'package:tw_server/src/schedules/schedules_dao.dart';

class ScheduleResource(ScheduleRecord record) extends Resource {
  this : super('schedules', record.id) {
    attributes.addAll({
      'name': record.name,
      'interval_miles': record.intervalMiles,
      'interval_months': record.intervalMonths,
      'details': record.details,
    });
    relationships['vehicle'] = ToOne(Identifier('vehicles', record.vehicleId));
  }
}
