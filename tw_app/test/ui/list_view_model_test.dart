import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:tw_app/testing/stub.dart' as stub;
import 'package:tw_app/testing/samples.dart' as samples;
import 'package:tw_app/ui/list_view_model.dart';

void main() {
  group('ListViewModel', () {
    late stub.InMemoryVehicleRepo repo;
    late ListViewModel<Vehicle> model;
    ({bool loading, bool error, List<Vehicle> items})? observed;

    setUp(() {
      repo = stub.InMemoryVehicleRepo(initialVehicles: samples.sampleVehicles);
      model = ListViewModel<Vehicle>(fetch: repo.list);
      observed = null;
      model.addListener(() {
        observed = (loading: model.isLoading, error: model.hasError, items: List.of(model.items));
      });
    });

    test('failed loading can be retried successfully', () async {
      addTearDown(model.dispose);

      expect(model.hasError, isFalse);
      expect(model.isLoading, isFalse);
      expect(model.items, isEmpty);

      var completer = repo.pauseNextList();
      final result = model.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.items, isEmpty);

      final error = Exception('Network error');
      completer.completeError(error);
      await result;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isTrue);
      expect(observed?.items, isEmpty);

      completer = repo.pauseNextList();

      final result2 = model.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.items, isEmpty);

      completer.complete();
      await result2;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isFalse);
      expect(observed?.items, equals(samples.sampleVehicles));
    });

    test('retry succeeds without arranging another response', () async {
      addTearDown(model.dispose);
      final completer = repo.pauseNextList();
      final firstLoad = model.load();

      completer.completeError(Exception('Network error'));
      await firstLoad;
      expect(model.hasError, isTrue);

      await model.load();

      expect(model.hasError, isFalse);
      expect(model.isLoading, isFalse);
      expect(model.items, equals(samples.sampleVehicles));
    });

    test('loaded items cannot be modified by consumers', () async {
      addTearDown(model.dispose);
      await model.load();

      expect(() => model.items.clear(), throwsUnsupportedError);
      expect(model.items, equals(samples.sampleVehicles));
    });

    test('stops notifying after disposal', () async {
      final completer = repo.pauseNextList();
      final res = model.load();
      observed = null;
      model.dispose();
      completer.complete();
      await res;
      expect(observed, isNull);
    });

    test('handles failed loading after disposal', () async {
      final completer = repo.pauseNextList();
      final res = model.load();
      observed = null;
      model.dispose();
      completer.completeError(Exception('Network error'));
      await res;
      expect(observed, isNull);
    });
  });
}
