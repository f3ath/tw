import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:test/test.dart';

void main() {
  test('resolves lastPerformed from an included service', () {
    final vehicle = ToOne(Identifier(ResourceType.vehicles, 'vehicle-id'));
    final service = Resource(ResourceType.services, 'service-id')
      ..attributes.addAll({'date': '2026-01-10', 'odometer': 12000, 'details': ''})
      ..relationships['vehicle'] = vehicle;
    final resource = Resource(ResourceType.schedules, 'schedule-id')
      ..attributes.addAll({'name': 'Oil change', 'interval_months': 6, 'details': ''})
      ..relationships['vehicle'] = vehicle
      ..relationships['lastPerformed'] = ToOne(Identifier(service.type, service.id));

    final unrelatedService = Resource(ResourceType.services, 'unrelated-service-id')
      ..attributes.addAll(service.attributes)
      ..relationships['vehicle'] = vehicle;

    final schedule = resource.toSchedule(included: [unrelatedService, service]);

    expect(schedule.lastPerformed, isA<Service>().having((value) => value.id, 'id', service.id));
    expect(schedule.nextDue, isNull);
  });

  test('reads nextDue from the schedule attributes', () {
    final resource = Resource(ResourceType.schedules, 'schedule-id')
      ..attributes.addAll({
        'name': 'Oil change',
        'interval_months': 6,
        'details': '',
        'nextDue': {'date': '2026-07-10'},
      })
      ..relationships['vehicle'] = ToOne(Identifier(ResourceType.vehicles, 'vehicle-id'));

    expect(resource.toSchedule().nextDue, (date: CalendarDate(2026, 7, 10), odometer: null));
  });

  group('Vehicle odometer parsing', () {
    late Resource resource;

    setUp(() {
      resource = Resource(ResourceType.vehicles, 'vehicle-id')
        ..attributes.addAll({
          'name': 'Civic',
          'manufacture_date': '2020-05-01',
          'mileage_unit': 'mi',
        });
    });

    test('preserves the reading and its calendar date', () {
      resource.attributes['odometer'] = {'value': 0, 'date': '2024-01-15'};

      final odometer = resource.toVehicle().odometer!;
      expect(odometer.value, 0);
      expect(odometer.date, CalendarDate(2024, 1, 15));
    });

    test('allows an omitted or null reading', () {
      expect(resource.toVehicle().odometer, isNull);

      resource.attributes['odometer'] = null;
      expect(resource.toVehicle().odometer, isNull);
    });

    test('rejects malformed readings', () {
      for (final reading in [
        150,
        {'value': 150},
        {'value': '150', 'date': '2024-01-15'},
        {'value': -1, 'date': '2024-01-15'},
        {'value': 150, 'date': '2024-02-30'},
        {'value': 150, 'date': '2024-01-15T00:00:00Z'},
      ]) {
        resource.attributes['odometer'] = reading;
        expect(resource.toVehicle, throwsFormatException, reason: '$reading');
      }
    });
  });
}
