import 'package:json_api/document.dart';

class const Vehicle({
  required final String id,
  required final String name,
  required final DateTime manufactureDate,
  required final String distanceUnit,
}) {
  static Vehicle fromResource(Resource resource) => Vehicle(
    id: resource.id,
    name: resource.attributes['name'] as String,
    manufactureDate: DateTime.parse(resource.attributes['manufacture_date'] as String),
    distanceUnit: resource.attributes['distance_unit'] as String,
  );
}
