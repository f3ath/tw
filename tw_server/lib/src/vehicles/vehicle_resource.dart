import 'package:json_api/document.dart';
import 'package:tw_server/src/json_api/resource_type.dart';
import 'package:tw_server/src/vehicles/vehicles_dao.dart';

class VehicleResource(VehicleRecord record) extends Resource {
  this : super(ResourceType.vehicles, record.id) {
    attributes.addAll({
      'name': record.name,
      'manufacture_date': record.manufactureDate.toIso8601String().split('T').first,
    });
  }
}
