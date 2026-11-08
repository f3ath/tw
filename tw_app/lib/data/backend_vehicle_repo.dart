import 'package:json_api/document.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/data/api_client.dart';
import 'package:tw_app/domain/vehicle.dart';

class BackendVehicleRepo(final ApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> listVehicles() async {
    final r = await _client.fetchCollection('vehicles');
    return r.collection.map(_vehicle).toList();
  }

  @override
  Future<Vehicle> createVehicle({
    required String name,
    required DateTime manufactureDate,
    required DistanceUnit distanceUnit,
  }) async {
    final response = await _client.createNew(
      'vehicles',
      attributes: {
        'name': name,
        'manufacture_date': manufactureDate.toIso8601String().split('T').first,
        'distance_unit': distanceUnit.name,
      },
    );
    return _vehicle(response.resource);
  }

  Vehicle _vehicle(Resource it) => Vehicle(
    it.id,
    name: it.attributes['name'] as String,
    manufactureDate:
        tryParseDate(it.attributes['manufacture_date']) ??
        (throw const FormatException('Invalid manufacture_date')),
    distanceUnit: DistanceUnit.values.byName(it.attributes['distance_unit'] as String),
  );
}

DateTime? tryParseDate(Object? value) {
  if (value is! String) return null;
  final date = DateTime.tryParse(value);
  if (date == null || date.toIso8601String().split('T').first != value) return null;
  return date;
}
