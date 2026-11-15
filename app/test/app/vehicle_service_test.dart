import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:app/testing/samples.dart' as samples;

void main() {
  group('VehicleService', () {
    test('retains a matching vehicle and service', () {
      final pair = VehicleService(vehicle: samples.santaFe, service: samples.santaFeOilService);

      expect(pair.vehicle, same(samples.santaFe));
      expect(pair.service, same(samples.santaFeOilService));
    });

    test('rejects a service belonging to a different vehicle', () {
      expect(
        () => VehicleService(vehicle: samples.santaFe, service: samples.fourRunnerTireService),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'service')),
      );
    });

    test('matches by vehicle ID rather than instance identity', () {
      final original = samples.santaFe;
      final vehicle = Vehicle(
        original.id,
        name: 'Updated vehicle name',
        manufactureDate: original.manufactureDate,
        distanceUnit: original.distanceUnit,
      );

      final pair = VehicleService(vehicle: vehicle, service: samples.santaFeOilService);

      expect(pair.vehicle, same(vehicle));
      expect(pair.service.vehicleId, equals(vehicle.id));
    });
  });
}
