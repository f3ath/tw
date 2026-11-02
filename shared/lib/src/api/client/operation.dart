import 'package:json_api/document.dart';

class const Operation(
  final String id, {
  required final String serviceId,
  required final String name,
  required final String details,
  final String? scheduleId,
}) {
  static Operation fromResource(Resource resource) => Operation(
    resource.id,
    serviceId: resource.one('service')!.single.id,
    name: resource.attributes['name'] as String,
    details: resource.attributes['details'] as String,
    scheduleId: resource.one('schedule')?.singleOrNull?.id,
  );
}
