import 'package:json_api/document.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';

extension ModelResource on Resource {
  Vehicle toVehicle() => Vehicle(
    id,
    name: attributes['name'] as String,
    manufactureDate:
        tryParseDate(attributes['manufacture_date']) ??
        (throw const FormatException('Invalid manufacture_date')),
    distanceUnit: DistanceUnit.values.byName(attributes['distance_unit'] as String),
  );

  User toUser() =>
      User(id, name: attributes['name'] as String, email: attributes['email'] as String);

  Session toSession() {
    final redirect = attributes['redirect'];
    return Session(id, completionUri: redirect is String ? Uri.parse(redirect) : null);
  }

  Service toService() => Service(
    id,
    vehicleId: one('vehicle')!.single.id,
    date: tryParseDate(attributes['date']) ?? (throw const FormatException('Invalid date')),
    odometer: attributes['odometer'] as int,
    details: attributes['details'] as String,
  );

  Schedule toSchedule() => Schedule(
    id: id,
    vehicleId: relationships['vehicle']!.single.id,
    name: attributes['name'] as String,
    intervalDistance: attributes['interval_distance'] as int?,
    intervalMonths: attributes['interval_months'] as int?,
    details: attributes['details'] as String,
    isArchived: attributes['is_archived'] as bool? ?? false,
  );

  Operation toOperation() => Operation(
    id,
    serviceId: one('service')!.single.id,
    name: attributes['name'] as String,
    details: attributes['details'] as String,
    scheduleId: one('schedule')?.singleOrNull?.id,
  );
}
