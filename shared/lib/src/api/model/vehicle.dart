import 'package:json_api/document.dart';
import 'package:shared/src/api/model/distance_unit.dart';
import 'package:shared/time.dart';

class const Vehicle(
  final String id, {
  required final String name,
  required final DateTime manufactureDate,
  required final DistanceUnit distanceUnit,
});

extension ResourceToVehicleExt on Resource {
  Vehicle toVehicle() => Vehicle(
    id,
    name: attributes['name'] as String,
    manufactureDate:
        tryParseDate(attributes['manufacture_date']) ??
        (throw const FormatException('Invalid manufacture_date')),
    distanceUnit: DistanceUnit.values.byName(attributes['distance_unit'] as String),
  );
}
