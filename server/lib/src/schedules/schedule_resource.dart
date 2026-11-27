import 'package:json_api/document.dart';
import 'package:server/src/schedules/schedules_dao.dart';
import 'package:server/src/services/service_resource.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';

class ScheduleResource(ScheduleRecord record) extends Resource {
  this : super(ResourceType.schedules, record.id) {
    attributes.addAll({
      'name': record.name,
      'interval_distance': record.intervalDistance,
      'interval_months': record.intervalMonths,
      'details': record.details,
      'is_archived': record.isArchived,
    });
    relationships['vehicle'] = ToOne(Identifier(ResourceType.vehicles, record.vehicleId));
  }

  static OutboundDataDocument document(ScheduleRecord record) =>
      OutboundDataDocument.resource(ScheduleResource(record));

  static OutboundDataDocument collection(Iterable<ScheduleRecord> records) =>
      OutboundDataDocument.collection(records.map(ScheduleResource.new));

  static OutboundDataDocument vehicleCollection(
    Iterable<ScheduleRecord> records,
    CalendarDate manufactureDate,
  ) {
    final schedules = <ScheduleResource>[];
    final services = <String, ServiceResource>{};
    for (final record in records) {
      final schedule = ScheduleResource(record);
      final performed = record.lastPerformed;
      schedule.attributes['nextDue'] = _nextDueAttributes(record, manufactureDate);
      schedule.relationships['lastPerformed'] = ToOne(
        performed == null ? null : Identifier(ResourceType.services, performed.id),
      );
      schedules.add(schedule);
      if (performed != null) {
        services.putIfAbsent(performed.id, () => ServiceResource(performed));
      }
    }
    return OutboundDataDocument.collection(schedules)..included.addAll(services.values);
  }

  static Map<String, Object> _nextDueAttributes(
    ScheduleRecord record,
    CalendarDate manufactureDate,
  ) {
    final performed = record.lastPerformed;
    final months = record.intervalMonths;
    final distance = record.intervalDistance;
    final baseDate = performed?.date ?? manufactureDate;
    return {
      if (months != null) 'date': baseDate.addDays(30 * months).toIsoDateString(),
      if (distance != null) 'odometer': (performed?.odometer ?? 0) + distance,
    };
  }
}
