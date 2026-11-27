import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:app/app/vehicle_schedule.dart';
import 'package:app/testing/samples.dart' as samples;

void main() {
  group('VehicleSchedule', () {
    test('retains a matching vehicle and schedule', () {
      final pair = VehicleSchedule(vehicle: samples.santaFe, schedule: samples.oilChange);

      expect(pair.vehicle, same(samples.santaFe));
      expect(pair.schedule, same(samples.oilChange));
    });

    test('rejects a schedule belonging to a different vehicle', () {
      expect(
        () => VehicleSchedule(vehicle: samples.santaFe, schedule: samples.tireRotation),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'schedule')),
      );
    });

    test('matches by vehicle ID rather than instance identity', () {
      final original = samples.santaFe;
      final vehicle = Vehicle(
        original.id,
        name: 'Updated vehicle name',
        manufactureDate: original.manufactureDate,
        mileageUnit: original.mileageUnit,
      );

      final pair = VehicleSchedule(vehicle: vehicle, schedule: samples.oilChange);

      expect(pair.vehicle, same(vehicle));
      expect(pair.schedule.vehicleId, equals(vehicle.id));
    });
  });
}
