import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/application/vehicle_repository.dart';
import 'package:tw_app/domain/vehicle.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/ui/garage/garage_view_model.dart';

void main() {
  group('GarageViewModel', () {
    late VehicleRepositoryFake repo;
    late GarageViewModel garageVM;
    ({bool loading, bool error, List<Vehicle> vehicles})? observed;

    setUp(() {
      repo = VehicleRepositoryFake();
      garageVM = GarageViewModel(vehicleRepository: repo);
      observed = null;
      garageVM.addListener(() {
        observed = (
          loading: garageVM.isLoading,
          error: garageVM.hasError,
          vehicles: List.of(garageVM.vehicles),
        );
      });
    });

    tearDown(() => garageVM.dispose());

    test('failed loading can be retried successfully', () async {
      expect(garageVM.hasError, isFalse);
      expect(garageVM.isLoading, isFalse);
      expect(garageVM.vehicles, isEmpty);

      final result = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      final error = Exception('Network error');
      repo.completer.completeError(error);
      await result;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isTrue);
      expect(observed?.vehicles, isEmpty);

      repo.reset();

      final result2 = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      repo.completer.complete(stub.vehicles);
      await result2;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, equals(stub.vehicles));
    });
  });
}

class VehicleRepositoryFake implements VehicleRepository {
  void reset() {
    completer = Completer<List<Vehicle>>();
  }

  var completer = Completer<List<Vehicle>>();

  @override
  Future<List<Vehicle>> listVehicles() => completer.future;
}
