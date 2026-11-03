import 'package:json_api/document.dart';
import 'package:shared/time.dart';

class const Service(
  final String id, {
  required final String vehicleId,
  required final DateTime date,
  required final int odometer,
  required final String details,
}) {
  static Service fromResource(Resource resource) => Service(
    resource.id,
    vehicleId: resource.one('vehicle')!.single.id,
    date:
        tryParseDate(resource.attributes['date']) ?? (throw const FormatException('Invalid date')),
    odometer: resource.attributes['odometer'] as int,
    details: resource.attributes['details'] as String,
  );
}
