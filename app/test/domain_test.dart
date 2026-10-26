import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/policies.dart';

void main() {
  final today = DateTime(2026, 10, 25);
  final vehicle = Vehicle(
    id: 'v',
    name: 'Car',
    manufactured: today.subtract(const Duration(days: 180)),
    unit: 'km',
  );
  Garage garage(MaintenanceItem item, {int? mileage = 5000}) => Garage(
    asOf: today,
    vehicles: [vehicle],
    items: [item],
    services: [
      if (mileage != null) ServiceRecord(id: 's', vehicleId: 'v', date: today, mileage: mileage),
    ],
  );
  const policy = SchedulingPolicy();
  test('exact date and distance thresholds are overdue and counted once', () {
    const item = MaintenanceItem(
      id: 'i',
      vehicleId: 'v',
      description: 'Oil',
      distance: 5000,
      months: 6,
    );
    final data = garage(item);
    expect(policy.calculate(data, item).status, DueStatus.overdue);
    expect(policy.due(data, 'v'), hasLength(1));
    expect(policy.calculate(data, item).reason('km'), contains('Due today'));
    expect(policy.calculate(data, item).reason('km'), contains('Due now'));
  });
  test('1000 units and 30 days inclusive are due soon', () {
    const distance = MaintenanceItem(id: 'i', vehicleId: 'v', description: 'Oil', distance: 6000);
    expect(policy.calculate(garage(distance), distance).status, DueStatus.soon);
    const date = MaintenanceItem(id: 'i', vehicleId: 'v', description: 'Oil', months: 7);
    expect(policy.calculate(garage(date), date).daysRemaining, 30);
    expect(policy.calculate(garage(date), date).status, DueStatus.soon);
  });
  test(
    'mileage only and custom text do not reset; latest linked completion ordered by mileage and id',
    () {
      const item = MaintenanceItem(id: 'i', vehicleId: 'v', description: 'Oil', distance: 5000);
      final a = ServiceRecord(id: 'a', vehicleId: 'v', date: today, mileage: 4000, links: ['i']);
      final b = ServiceRecord(id: 'b', vehicleId: 'v', date: today, mileage: 4500, links: ['i']);
      final c = ServiceRecord(id: 'c', vehicleId: 'v', date: today, mileage: 5000, custom: ['Oil']);
      final data = garage(item).copy(services: [a, b, c]);
      expect(policy.calculate(data, item).distanceDue, 9500);
      expect(policy.calculate(data, item).last!.id, 'b');
    },
  );
  test('missing mileage is incomplete while known time still works', () {
    const item = MaintenanceItem(id: 'i', vehicleId: 'v', description: 'Oil', distance: 5000);
    expect(policy.calculate(garage(item, mileage: null), item).status, DueStatus.incomplete);
    const timed = MaintenanceItem(
      id: 'i',
      vehicleId: 'v',
      description: 'Oil',
      distance: 5000,
      months: 1,
    );
    expect(policy.calculate(garage(timed, mileage: null), timed).status, DueStatus.overdue);
  });
  test(
    'odometer chronological neighbors, equal readings, edit exclusion and same day ordering',
    () {
      final a = ServiceRecord(
        id: 'a',
        vehicleId: 'v',
        date: today.subtract(const Duration(days: 2)),
        mileage: 100,
      );
      final b = ServiceRecord(id: 'b', vehicleId: 'v', date: today, mileage: 200);
      final data = Garage(asOf: today, vehicles: [vehicle], services: [a, b]);
      const validation = ValidationPolicy();
      expect(
        () => validation.service(
          data,
          ServiceRecord(
            id: 'new',
            vehicleId: 'v',
            date: today.subtract(const Duration(days: 1)),
            mileage: 99,
          ),
          today,
        ),
        throwsA(isA<AppFailure>()),
      );
      validation.service(
        data,
        ServiceRecord(
          id: 'new',
          vehicleId: 'v',
          date: today.subtract(const Duration(days: 1)),
          mileage: 100,
        ),
        today,
      );
      validation.service(
        data,
        ServiceRecord(id: 'b', vehicleId: 'v', date: today, mileage: 300),
        today,
      );
      validation.service(
        data,
        ServiceRecord(id: 'new', vehicleId: 'v', date: today, mileage: 150),
        today,
      );
      expect(
        () => validation.service(
          data,
          ServiceRecord(
            id: 'new',
            vehicleId: 'v',
            date: today.add(const Duration(days: 1)),
            mileage: 300,
          ),
          today,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
