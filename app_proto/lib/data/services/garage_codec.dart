import '../../domain/models.dart';

class const GarageCodec() {
  Map<String, Object?> encode(Garage garage) => {
    'version': 2,
    'asOf': garage.asOf.toIso8601String(),
    'vehicles': [
      for (final vehicle in garage.vehicles)
        {
          'id': vehicle.id,
          'name': vehicle.name,
          'date': dateText(vehicle.manufactureDate),
          'unit': vehicle.distanceUnit.name,
        },
    ],
    'items': [
      for (final item in garage.items)
        {
          'id': item.id,
          'vehicle': item.vehicleId,
          'name': item.name,
          'details': item.details,
          'distance': item.intervalDistance,
          'months': item.intervalMonths,
          'archived': item.isArchived,
        },
    ],
    'services': [
      for (final service in garage.services)
        {
          'id': service.id,
          'vehicle': service.vehicleId,
          'date': dateText(service.date),
          'odometer': service.odometer,
          'details': service.details,
        },
    ],
    'operations': [
      for (final operation in garage.operations)
        {
          'id': operation.id,
          'service': operation.serviceId,
          'schedule': operation.scheduleId,
          'name': operation.name,
          'details': operation.details,
        },
    ],
  };

  Garage decode(Map<String, Object?> json) {
    final serviceRows = rows(json, 'services').toList();
    return Garage(
      asOf: DateTime.parse(json['asOf'] as String),
      vehicles: rows(json, 'vehicles').map(
        (vehicle) => Vehicle(
          vehicle['id'] as String,
          name: vehicle['name'] as String,
          manufactureDate: day(DateTime.parse(vehicle['date'] as String)),
          distanceUnit: DistanceUnit.values.byName(vehicle['unit'] as String),
        ),
      ),
      items: rows(json, 'items').map(
        (item) => Schedule(
          id: item['id'] as String,
          vehicleId: item['vehicle'] as String,
          name: (item['name'] ?? item['description']) as String,
          details: item['details'] as String? ?? '',
          intervalDistance: item['distance'] as int?,
          intervalMonths: item['months'] as int?,
          isArchived: item['archived'] as bool,
        ),
      ),
      services: serviceRows.map(
        (service) => Service(
          service['id'] as String,
          vehicleId: service['vehicle'] as String,
          date: day(DateTime.parse(service['date'] as String)),
          odometer: (service['odometer'] ?? service['mileage']) as int,
          details: service['details'] as String? ?? '',
        ),
      ),
      operations: json.containsKey('operations')
          ? rows(json, 'operations').map(
              (operation) => Operation(
                operation['id'] as String,
                serviceId: operation['service'] as String,
                scheduleId: operation['schedule'] as String?,
                name: operation['name'] as String,
                details: operation['details'] as String,
              ),
            )
          : _legacyOperations(serviceRows),
    );
  }

  Iterable<Operation> _legacyOperations(List<Map<String, Object?>> services) sync* {
    for (final service in services) {
      final serviceId = service['id'] as String;
      for (final id in (service['links'] as List).cast<String>()) {
        yield Operation(
          '$serviceId:schedule:$id',
          serviceId: serviceId,
          scheduleId: id,
          name: '',
          details: '',
        );
      }
      final custom = (service['custom'] as List).cast<String>();
      for (var index = 0; index < custom.length; index++) {
        yield Operation(
          '$serviceId:custom:$index',
          serviceId: serviceId,
          name: custom[index],
          details: '',
        );
      }
    }
  }

  Iterable<Map<String, Object?>> rows(Map<String, Object?> json, String key) =>
      (json[key] as List).map((row) => Map<String, Object?>.from(row as Map));
}
