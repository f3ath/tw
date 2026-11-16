import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/list_view_model.dart';

void main() {
  group('ListViewModel', () {
    late Future<List<String>> Function() fetch;
    late ListViewModel<String> model;
    ({bool loading, bool error, List<String> items})? observed;

    setUp(() {
      fetch = () async => ['first', 'second'];
      model = ListViewModel<String>(fetch: () => fetch());
      addTearDown(model.dispose);
      observed = null;
      model.addListener(() {
        observed = (loading: model.isLoading, error: model.hasError, items: List.of(model.items));
      });
    });

    test('failed loading can be retried successfully', () async {
      expect(model.hasError, isFalse);
      expect(model.isLoading, isFalse);
      expect(model.items, isEmpty);

      var completer = Completer<List<String>>();
      fetch = () => completer.future;
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

      completer = Completer<List<String>>();

      final result2 = model.load();
      expect(observed?.loading, isTrue);
      expect(observed?.error, isFalse);
      expect(observed?.items, isEmpty);

      completer.complete(['first', 'second']);
      await result2;

      expect(observed?.loading, isFalse);
      expect(observed?.error, isFalse);
      expect(observed?.items, equals(['first', 'second']));
    });

    test('retry uses a fresh fetch callback result', () async {
      final completer = Completer<List<String>>();
      fetch = () => completer.future;
      final firstLoad = model.load();

      completer.completeError(Exception('Network error'));
      await firstLoad;
      expect(model.hasError, isTrue);

      fetch = () async => ['first', 'second'];
      await model.load();

      expect(model.hasError, isFalse);
      expect(model.isLoading, isFalse);
      expect(model.items, equals(['first', 'second']));
    });

    for (final olderFails in [false, true]) {
      test('older ${olderFails ? 'failure' : 'success'} cannot replace newer success', () async {
        final older = Completer<List<String>>();
        final newer = Completer<List<String>>();
        fetch = () => older.future;
        final firstLoad = model.load();
        fetch = () => newer.future;
        final secondLoad = model.load();

        newer.complete(['newer']);
        await secondLoad;
        observed = null;
        if (olderFails) {
          older.completeError(Exception('Old request failed'));
        } else {
          older.complete(['older']);
        }
        await firstLoad;

        expect(model.items, equals(['newer']));
        expect(model.hasError, isFalse);
        expect(model.isLoading, isFalse);
        expect(observed, isNull);
      });

      test('older ${olderFails ? 'failure' : 'success'} leaves newer load pending', () async {
        final older = Completer<List<String>>();
        final newer = Completer<List<String>>();
        fetch = () => older.future;
        final firstLoad = model.load();
        fetch = () => newer.future;
        final secondLoad = model.load();
        observed = null;

        if (olderFails) {
          older.completeError(Exception('Old request failed'));
        } else {
          older.complete(['older']);
        }
        await firstLoad;

        expect(model.isLoading, isTrue);
        expect(model.hasError, isFalse);
        expect(model.items, isEmpty);
        expect(observed, isNull);

        newer.complete(['newer']);
        await secondLoad;
        expect(model.isLoading, isFalse);
        expect(model.items, equals(['newer']));
      });
    }

    test('older success cannot replace newer failure', () async {
      await model.load();
      final older = Completer<List<String>>();
      final newer = Completer<List<String>>();
      fetch = () => older.future;
      final firstLoad = model.load();
      fetch = () => newer.future;
      final secondLoad = model.load();

      newer.completeError(Exception('Latest request failed'));
      await secondLoad;
      expect(model.hasError, isTrue);
      expect(model.isLoading, isFalse);
      observed = null;
      older.complete(['older']);
      await firstLoad;

      expect(model.items, equals(['first', 'second']));
      expect(model.hasError, isTrue);
      expect(model.isLoading, isFalse);
      expect(observed, isNull);
    });

    test('loaded items cannot be modified by consumers', () async {
      await model.load();

      expect(() => model.items.clear(), throwsUnsupportedError);
      expect(model.items, equals(['first', 'second']));
    });

    test('stops notifying after disposal', () async {
      final completer = Completer<List<String>>();
      fetch = () => completer.future;
      final res = model.load();
      observed = null;
      model.dispose();
      completer.complete(['first', 'second']);
      await res;
      expect(observed, isNull);
    });

    test('handles failed loading after disposal', () async {
      final completer = Completer<List<String>>();
      fetch = () => completer.future;
      final res = model.load();
      observed = null;
      model.dispose();
      completer.completeError(Exception('Network error'));
      await res;
      expect(observed, isNull);
    });

    test('load exits immediately if disposed', () async {
      var fetchCalls = 0;
      fetch = () async {
        fetchCalls++;
        return ['unexpected'];
      };
      model.dispose();

      await model.load();

      expect(fetchCalls, isZero);
      expect(observed, isNull);
    });

    test('double dispose is tolerated', () async {
      model.dispose();
      model.dispose();
    });
  });
}
