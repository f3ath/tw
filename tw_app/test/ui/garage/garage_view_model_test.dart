import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/ui/garage/garage_view_model.dart';

void main() {
  group('GarageViewModel', () {
    late stub.InMemoryVehicleRepo repo;
    late GarageViewModel garageVM;
    ({bool loading, bool error, List<Vehicle> vehicles})? observed;

    setUp(() {
      repo = stub.InMemoryVehicleRepo(initialVehicles: samples.sampleVehicles);
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

      var completer = repo.pauseNextList();
      final result = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      final error = Exception('Network error');
      completer.completeError(error);
      await result;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isTrue);
      expect(observed?.vehicles, isEmpty);

      completer = repo.pauseNextList();

      final result2 = garageVM.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, isEmpty);

      completer.complete();
      await result2;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isFalse);
      expect(observed?.vehicles, equals(samples.sampleVehicles));
    });

    test('retry succeeds without arranging another response', () async {
      addTearDown(garageVM.dispose);
      final completer = repo.pauseNextList();
      final firstLoad = garageVM.load();

      completer.completeError(Exception('Network error'));
      await firstLoad;
      expect(garageVM.hasError, isTrue);

      await garageVM.load();

      expect(garageVM.hasError, isFalse);
      expect(garageVM.isLoading, isFalse);
      expect(garageVM.vehicles, equals(samples.sampleVehicles));
    });

    test('stops notifying after disposal', () async {
      final completer = repo.pauseNextList();
      final res = garageVM.load();
      observed = null;
      garageVM.dispose();
      completer.complete();
      await res;
      expect(observed, isNull);
    });

    test('handles failed loading after error', () async {
      final completer = repo.pauseNextList();
      final res = garageVM.load();
      observed = null;
      garageVM.dispose();
      completer.completeError(Exception('Network error'));
      await res;
      expect(observed, isNull);
    });
  });
}
