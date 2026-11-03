import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/policies.dart';

void main() {
  final today = DateTime(2026, 10, 25);
  final vehicle = Vehicle(
    'v',
    name: 'Car',
    manufactureDate: today.subtract(const Duration(days: 180)),
    distanceUnit: DistanceUnit.km,
  );
  Garage garage(Schedule item, {int? odometer = 5000}) => Garage(
    asOf: today,
    vehicles: [vehicle],
    items: [item],
    services: [
      if (odometer != null)
        Service('s', vehicleId: 'v', date: today, odometer: odometer, details: ''),
    ],
  );
  const policy = SchedulingPolicy();
  test('exact date and distance thresholds are overdue and counted once', () {
    const item = Schedule(
      id: 'i',
      vehicleId: 'v',
      name: 'Oil',
      intervalDistance: 5000,
      intervalMonths: 6,
      details: '',
    );
    final data = garage(item);
    expect(policy.calculate(data, item).status, DueStatus.overdue);
    expect(policy.due(data, 'v'), hasLength(1));
    expect(policy.calculate(data, item).reason('km'), contains('Due today'));
    expect(policy.calculate(data, item).reason('km'), contains('Due now'));
  });
  test('1000 units and 30 days inclusive are due soon', () {
    const distance = Schedule(
      id: 'i',
      vehicleId: 'v',
      name: 'Oil',
      intervalDistance: 6000,
      details: '',
      intervalMonths: null,
    );
    expect(policy.calculate(garage(distance), distance).status, DueStatus.soon);
    const date = Schedule(
      id: 'i',
      vehicleId: 'v',
      name: 'Oil',
      intervalMonths: 7,
      details: '',
      intervalDistance: null,
    );
    expect(policy.calculate(garage(date), date).daysRemaining, 30);
    expect(policy.calculate(garage(date), date).status, DueStatus.soon);
  });
  test(
    'mileage only and custom text do not reset; latest linked completion ordered by mileage and id',
    () {
      const item = Schedule(
        id: 'i',
        vehicleId: 'v',
        name: 'Oil',
        intervalDistance: 5000,
        details: '',
        intervalMonths: null,
      );
      final a = Service('a', vehicleId: 'v', date: today, odometer: 4000, details: '');
      final b = Service('b', vehicleId: 'v', date: today, odometer: 4500, details: '');
      final c = Service('c', vehicleId: 'v', date: today, odometer: 5000, details: '');
      final data = garage(item).copy(
        services: [a, b, c],
        operations: [
          Operation('a-i', serviceId: a.id, scheduleId: item.id, name: 'Oil', details: ''),
          Operation('b-i', serviceId: b.id, scheduleId: item.id, name: 'Oil', details: ''),
          Operation('c-custom', serviceId: c.id, name: 'Oil', details: ''),
        ],
      );
      expect(policy.calculate(data, item).distanceDue, 9500);
      expect(policy.calculate(data, item).last!.id, 'b');
    },
  );
  test('missing mileage is incomplete while known time still works', () {
    const item = Schedule(
      id: 'i',
      vehicleId: 'v',
      name: 'Oil',
      intervalDistance: 5000,
      details: '',
      intervalMonths: null,
    );
    expect(policy.calculate(garage(item, odometer: null), item).status, DueStatus.incomplete);
    const timed = Schedule(
      id: 'i',
      vehicleId: 'v',
      name: 'Oil',
      intervalDistance: 5000,
      intervalMonths: 1,
      details: '',
    );
    expect(policy.calculate(garage(timed, odometer: null), timed).status, DueStatus.overdue);
  });
  test(
    'odometer chronological neighbors, equal readings, edit exclusion and same day ordering',
    () {
      final a = Service(
        'a',
        vehicleId: 'v',
        date: today.subtract(const Duration(days: 2)),
        odometer: 100,
        details: '',
      );
      final b = Service('b', vehicleId: 'v', date: today, odometer: 200, details: '');
      final data = Garage(asOf: today, vehicles: [vehicle], services: [a, b]);
      const validation = ValidationPolicy();
      expect(
        () => validation.service(
          data,
          Service(
            'new',
            vehicleId: 'v',
            date: today.subtract(const Duration(days: 1)),
            odometer: 99,
            details: '',
          ),
          today,
        ),
        throwsA(isA<AppFailure>()),
      );
      validation.service(
        data,
        Service(
          'new',
          vehicleId: 'v',
          date: today.subtract(const Duration(days: 1)),
          odometer: 100,
          details: '',
        ),
        today,
      );
      validation.service(
        data,
        Service('b', vehicleId: 'v', date: today, odometer: 300, details: ''),
        today,
      );
      validation.service(
        data,
        Service('new', vehicleId: 'v', date: today, odometer: 150, details: ''),
        today,
      );
      validation.service(
        data,
        Service(
          'new',
          vehicleId: 'v',
          date: today.add(const Duration(days: 7)),
          odometer: 300,
          details: '',
        ),
        today,
      );
      expect(
        () => validation.service(
          data,
          Service(
            'new',
            vehicleId: 'v',
            date: today.add(const Duration(days: 8)),
            odometer: 300,
            details: '',
          ),
          today,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
