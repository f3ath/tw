import 'package:json_api/document.dart';
import 'package:shared/time.dart';

class const Service(
  final String id, {
  required final String vehicleId,
  required final DateTime date,
  required final int odometer,
  required final String details,
});

extension ResourceToServiceExt on Resource {
  Service toService() => Service(
    id,
    vehicleId: one('vehicle')!.single.id,
    date: tryParseDate(attributes['date']) ?? (throw const FormatException('Invalid date')),
    odometer: attributes['odometer'] as int,
    details: attributes['details'] as String,
  );
}
