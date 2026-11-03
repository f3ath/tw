import 'package:json_api/document.dart';
import 'package:shared/time.dart';
import 'package:shared/src/api/distance_unit.dart';

class const Vehicle(
  final String id, {
  required final String name,
  required final DateTime manufactureDate,
  required final DistanceUnit distanceUnit,
}) {
  static Vehicle fromResource(Resource resource) => Vehicle(
    resource.id,
    name: resource.attributes['name'] as String,
    manufactureDate:
        tryParseDate(resource.attributes['manufacture_date']) ??
        (throw const FormatException('Invalid manufacture_date')),
    distanceUnit: DistanceUnit.values.byName(resource.attributes['distance_unit'] as String),
  );
}
