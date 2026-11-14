import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tw_app/ui/form/form_submission_controller.dart';

void main() {
  group('FormSubmissionController', () {
    late FormSubmissionController controller;
    late List<({bool submitting, bool error})> observed;

    setUp(() {
      controller = FormSubmissionController();
      observed = [];
      controller.addListener(() {
        observed.add((submitting: controller.isSubmitting, error: controller.hasError));
      });
    });

    test('reports pending and successful completion', () async {
      addTearDown(controller.dispose);
      expect(controller.isSubmitting, isFalse);
      expect(controller.hasError, isFalse);
      final pending = Completer<void>();

      final result = controller.submit(() => pending.future);

      expect(controller.isSubmitting, isTrue);
      expect(observed, [(submitting: true, error: false)]);
      pending.complete();

      expect(await result, isTrue);
      expect(controller.isSubmitting, isFalse);
      expect(controller.hasError, isFalse);
      expect(observed.last, (submitting: false, error: false));
    });

    test('reports failure and clears the error when retry begins', () async {
      addTearDown(controller.dispose);
      final pending = Completer<void>();
      final first = controller.submit(() => pending.future);
      pending.completeError(Exception('Network error'));

      expect(await first, isFalse);
      expect(controller.isSubmitting, isFalse);
      expect(controller.hasError, isTrue);

      final retry = Completer<void>();
      final second = controller.submit(() => retry.future);

      expect(controller.isSubmitting, isTrue);
      expect(controller.hasError, isFalse);
      retry.complete();
      expect(await second, isTrue);
      expect(observed, [
        (submitting: true, error: false),
        (submitting: false, error: true),
        (submitting: true, error: false),
        (submitting: false, error: false),
      ]);
    });

    test('rejects another submission while pending without calling persistence', () async {
      addTearDown(controller.dispose);
      final pending = Completer<void>();
      var calls = 0;
      Future<void> persist() {
        calls++;
        return pending.future;
      }

      final first = controller.submit(persist);
      final duplicate = controller.submit(persist);

      expect(await duplicate, isFalse);
      expect(calls, equals(1));
      expect(controller.isSubmitting, isTrue);
      expect(observed, [(submitting: true, error: false)]);
      pending.complete();
      expect(await first, isTrue);
      expect(calls, equals(1));
    });

    test('handles a synchronous exception from persistence', () async {
      addTearDown(controller.dispose);

      final saved = await controller.submit(() => throw Exception('Cannot save'));

      expect(saved, isFalse);
      expect(controller.isSubmitting, isFalse);
      expect(controller.hasError, isTrue);
    });

    for (final fails in [false, true]) {
      test(
        'does not notify after disposal when persistence ${fails ? 'fails' : 'succeeds'}',
        () async {
          final pending = Completer<void>();
          final result = controller.submit(() => pending.future);
          observed.clear();
          controller.dispose();

          if (fails) {
            pending.completeError(Exception('Network error'));
          } else {
            pending.complete();
          }

          expect(await result, equals(!fails));
          expect(observed, isEmpty);
          var called = false;
          final saved = await controller.submit(() async => called = true);
          expect(saved, isFalse);
          expect(called, isFalse);
        },
      );
    }
  });
}
