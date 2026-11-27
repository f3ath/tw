import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:server/src/vehicles/vehicles_dao.dart';

class VehicleResource(VehicleRecord record) extends Resource {
  this : super(ResourceType.vehicles, record.id) {
    attributes.addAll({
      'name': record.name,
      'mileage_unit': record.mileageUnit.name,
      'manufacture_date': record.manufactureDate.toIsoDateString(),
    });
    final lastService = record.lastService;
    if (lastService != null) {
      attributes['odometer'] = {
        'value': lastService.odometer,
        'date': lastService.date.toIsoDateString(),
      };
      relationships['last_service'] = ToOne(Identifier(ResourceType.services, lastService.id));
    }
  }
}
