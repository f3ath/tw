import 'package:json_api/document.dart';
import 'package:shared/model.dart';
import 'package:shared/src/api/resource_type.dart';
import 'package:shared/time.dart';

extension ModelResource on Resource {
  Vehicle toVehicle() => Vehicle(
    id,
    name: attributes['name'] as String,
    manufactureDate:
        CalendarDate.tryParse(attributes['manufacture_date']) ??
        (throw const FormatException('Invalid manufacture_date')),
    mileageUnit: MileageUnit.values.byName(attributes['mileage_unit'] as String),
    odometer: switch (attributes['odometer']) {
      null => null,
      {'value': final int value && >= 0, 'date': final String date} => Odometer(
        date: CalendarDate.tryParse(date) ?? (throw const FormatException('Invalid odometer date')),
        value: value,
      ),
      _ => throw const FormatException('Invalid odometer'),
    },
  );

  User toUser() =>
      User(id, name: attributes['name'] as String, email: attributes['email'] as String);

  Session toSession() {
    final redirect = attributes['redirect'];
    return Session(id, completionUri: redirect is String ? Uri.parse(redirect) : null);
  }

  Service toService({List<Operation> operations = const []}) => Service(
    id,
    vehicleId: one('vehicle')!.single.id,
    date:
        CalendarDate.tryParse(attributes['date']) ?? (throw const FormatException('Invalid date')),
    odometer: attributes['odometer'] as int,
    details: attributes['details'] as String,
    operations: operations,
  );

  Schedule toSchedule({Iterable<Resource> included = const []}) {
    final serviceId = one('lastPerformed')?.singleOrNull?.id;
    final service = included
        .where((resource) => resource.type == ResourceType.services && resource.id == serviceId)
        .firstOrNull;
    return Schedule(
      id: id,
      vehicleId: relationships['vehicle']!.single.id,
      name: attributes['name'] as String,
      intervalDistance: attributes['interval_distance'] as int?,
      intervalMonths: attributes['interval_months'] as int?,
      details: attributes['details'] as String,
      isArchived: attributes['is_archived'] as bool? ?? false,
      lastPerformed: service?.toService(),
      nextDue: _scheduleNextDue(attributes['nextDue'] as Map<String, Object?>?),
    );
  }

  Operation toOperation() => Operation(
    id,
    serviceId: one('service')!.single.id,
    name: attributes['name'] as String,
    details: attributes['details'] as String,
    scheduleId: one('schedule')?.singleOrNull?.id,
  );
}

ScheduleNextDue? _scheduleNextDue(Map<String, Object?>? value) {
  if (value == null) return null;
  final date = value['date'];
  return (
    date: date == null
        ? null
        : CalendarDate.tryParse(date) ?? (throw const FormatException('Invalid nextDue date')),
    odometer: value['odometer'] as int?,
  );
}
