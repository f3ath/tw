import '../../domain/models.dart';

class const GarageCodec() {
  Map<String, Object?> encode(Garage g) => {
    'asOf': g.asOf.toIso8601String(),
    'vehicles': [
      for (final v in g.vehicles)
        {'id': v.id, 'name': v.name, 'date': v.manufactured.toIso8601String(), 'unit': v.unit},
    ],
    'items': [
      for (final i in g.items)
        {
          'id': i.id,
          'vehicle': i.vehicleId,
          'description': i.description,
          'distance': i.distance,
          'months': i.months,
          'archived': i.archived,
        },
    ],
    'services': [
      for (final s in g.services)
        {
          'id': s.id,
          'vehicle': s.vehicleId,
          'date': s.date.toIso8601String(),
          'mileage': s.mileage,
          'links': s.links,
          'custom': s.custom,
        },
    ],
  };
  Garage decode(Map<String, Object?> json) => Garage(
    asOf: DateTime.parse(json['asOf'] as String),
    vehicles: rows(json, 'vehicles').map(
      (v) => Vehicle(
        id: v['id'] as String,
        name: v['name'] as String,
        manufactured: DateTime.parse(v['date'] as String),
        unit: v['unit'] as String,
      ),
    ),
    items: rows(json, 'items').map(
      (i) => MaintenanceItem(
        id: i['id'] as String,
        vehicleId: i['vehicle'] as String,
        description: i['description'] as String,
        distance: i['distance'] as int?,
        months: i['months'] as int?,
        archived: i['archived'] as bool,
      ),
    ),
    services: rows(json, 'services').map(
      (s) => ServiceRecord(
        id: s['id'] as String,
        vehicleId: s['vehicle'] as String,
        date: DateTime.parse(s['date'] as String),
        mileage: s['mileage'] as int,
        links: (s['links'] as List).cast<String>(),
        custom: (s['custom'] as List).cast<String>(),
      ),
    ),
  );
  Iterable<Map<String, Object?>> rows(Map<String, Object?> json, String key) =>
      (json[key] as List).map((e) => Map<String, Object?>.from(e as Map));
}
