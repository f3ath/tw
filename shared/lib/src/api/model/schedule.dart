import 'package:json_api/document.dart';

class const Schedule({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int? intervalDistance,
  required final int? intervalMonths,
  required final String details,
  final bool isArchived = false,
});

extension ResourceToScheduleExt on Resource {
  Schedule toSchedule() => Schedule(
    id: id,
    vehicleId: relationships['vehicle']!.single.id,
    name: attributes['name'] as String,
    intervalDistance: attributes['interval_distance'] as int?,
    intervalMonths: attributes['interval_months'] as int?,
    details: attributes['details'] as String,
    isArchived: attributes['is_archived'] as bool? ?? false,
  );
}
