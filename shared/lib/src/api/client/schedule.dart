import 'package:json_api/document.dart';

class const Schedule({
  required final String id,
  required final String vehicleId,
  required final String name,
  required final int? intervalDistance,
  required final int? intervalMonths,
  required final String details,
  final bool isArchived = false,
}) {
  static Schedule fromResource(Resource resource) => Schedule(
    id: resource.id,
    vehicleId: resource.relationships['vehicle']!.single.id,
    name: resource.attributes['name'] as String,
    intervalDistance: resource.attributes['interval_distance'] as int?,
    intervalMonths: resource.attributes['interval_months'] as int?,
    details: resource.attributes['details'] as String,
    isArchived: resource.attributes['is_archived'] as bool? ?? false,
  );
}
