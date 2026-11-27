import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:test/test.dart';

void main() {
  test('date-only values preserve calendar components', () {
    final date = CalendarDate.tryParse('2026-11-01')!;
    expect(date, CalendarDate(2026, 11, 1));
  });

  test('reject invalid dates and timestamps', () {
    for (final value in [null, 123, '', '2026-02-30', '2026-1-1', '2026-11-01T00:00:00Z']) {
      expect(CalendarDate.tryParse(value), isNull, reason: '$value');
    }
  });

  test('vehicle and service DTOs preserve calendar dates', () {
    final resource = Resource(
      'vehicles',
      'vehicle-id',
    )..attributes.addAll({'name': 'Civic', 'manufacture_date': '2020-05-01', 'mileage_unit': 'mi'});
    final vehicle = resource.toVehicle();
    final service =
        (Resource('services', 'service-id')
              ..attributes.addAll({'date': '2024-01-15', 'odometer': 150, 'details': ''})
              ..relationships['vehicle'] = ToOne(Identifier('vehicles', 'vehicle-id')))
            .toService();
    expect(vehicle.manufactureDate, CalendarDate(2020, 5, 1));
    expect(service.date, CalendarDate(2024, 1, 15));
  });
}
