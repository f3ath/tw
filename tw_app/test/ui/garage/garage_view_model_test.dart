import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/fake.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/ui/garage/garage_view_model.dart';

void main() {
  group('GarageViewModel', () {
    late FakeVehicleRepo repo;
    late GarageViewModel garageVM;
    ({bool loading, bool error, List<Vehicle> vehicles})? observed;

    setUp(() {
      repo = FakeVehicleRepo();
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

    test('failed loading can be retried successfully', () async {
      addTearDown(garageVM.dispose);

      expect(garageVM.hasError, isFalse);
      expect(garageVM.isLoading, isFalse);
      expect(garageVM.vehicles, isEmpty);

      final result = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      final error = Exception('Network error');
      repo.listCompleter.completeError(error);
      await result;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isTrue);
      expect(observed?.vehicles, isEmpty);

      repo.reset();

      final result2 = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      repo.listCompleter.complete(stub.vehicles);
      await result2;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, equals(stub.vehicles));
    });

    test('stops notifying after disposal', () async {
      final res = garageVM.load();
      observed = null;
      garageVM.dispose();
      repo.listCompleter.complete([]);
      await res;
      expect(observed, isNull);
    });

    test('handles failed loading after error', () async {
      final res = garageVM.load();
      observed = null;
      garageVM.dispose();
      repo.listCompleter.completeError(Exception('Network error'));
      await res;
      expect(observed, isNull);
    });
  });
}
