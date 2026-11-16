import 'package:json_api/document.dart';
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:test/test.dart';

void main() {
  test('date-only values preserve calendar components', () {
    final date = tryParseDate('2026-11-01')!;
    expect(date, DateTime(2026, 11, 1));
    expect(date.isUtc, isFalse);
  });

  test('reject invalid dates and timestamps', () {
    for (final value in [null, 123, '', '2026-02-30', '2026-1-1', '2026-11-01T00:00:00Z']) {
      expect(tryParseDate(value), isNull, reason: '$value');
    }
  });

  test('vehicle and service DTOs preserve calendar dates', () {
    final resource = Resource('vehicles', 'vehicle-id')
      ..attributes.addAll({
        'name': 'Civic',
        'manufacture_date': '2020-05-01',
        'distance_unit': 'mi',
      });
    final vehicle = resource.toVehicle();
    final service =
        (Resource('services', 'service-id')
              ..attributes.addAll({'date': '2024-01-15', 'odometer': 150, 'details': ''})
              ..relationships['vehicle'] = ToOne(Identifier('vehicles', 'vehicle-id')))
            .toService();
    expect(vehicle.manufactureDate.isUtc, isFalse);
    expect(vehicle.manufactureDate, DateTime(2020, 5, 1));
    expect(service.date.isUtc, isFalse);
    expect(service.date, DateTime(2024, 1, 15));
  });
}
