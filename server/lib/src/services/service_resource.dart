import 'package:json_api/document.dart';
import 'package:server/src/services/services_tdao.dart';
import 'package:shared/api.dart';

class ServiceResource(ServiceRecord record) extends Resource {
  this : super(ResourceType.services, record.id) {
    attributes.addAll({
      'date': record.date.toIso8601String().split('T').first,
      'mileage': record.mileage,
      'details': record.details,
    });
    relationships['vehicle'] = ToOne(Identifier(ResourceType.vehicles, record.vehicleId));
  }
}
