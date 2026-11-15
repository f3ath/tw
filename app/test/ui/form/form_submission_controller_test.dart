import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/form/form_submission_controller.dart';

void main() {
  group('FormSubmissionController', () {
    late FormSubmissionController controller;
    late List<bool> observed;

    setUp(() {
      controller = FormSubmissionController();
      observed = [];
      controller.addListener(() {
        observed.add(controller.isSubmitting);
      });
    });

    test('reports pending and successful completion', () async {
      addTearDown(controller.dispose);
      expect(controller.isSubmitting, isFalse);
      final pending = Completer<void>();

      final result = controller.submit(() => pending.future);

      expect(controller.isSubmitting, isTrue);
      expect(observed, [true]);
      pending.complete();

      expect(await result, isA<SubmissionSuccess<void>>());
      expect(controller.isSubmitting, isFalse);
      expect(observed.last, false);
    });

    test('returns the persisted value in a typed success result', () async {
      addTearDown(controller.dispose);
      final pending = Completer<String>();
      final result = controller.submit(() => pending.future);

      pending.complete('saved-service');

      final saved = await result;
      expect(saved, isA<SubmissionSuccess<String>>());
      expect((saved as SubmissionSuccess<String>).value, equals('saved-service'));
    });

    test('a null persisted value is still a success', () async {
      addTearDown(controller.dispose);

      final result = await controller.submit<String?>(() async => null);

      expect(result, isA<SubmissionSuccess<String?>>());
      expect((result as SubmissionSuccess<String?>).value, isNull);
    });

    test('reports failure and allows a successful retry', () async {
      addTearDown(controller.dispose);
      final pending = Completer<void>();
      final first = controller.submit(() => pending.future);
      pending.completeError(Exception('Network error'));

      expect(await first, isA<SubmissionFailure<void>>());
      expect(controller.isSubmitting, isFalse);

      final retry = Completer<void>();
      final second = controller.submit(() => retry.future);

      expect(controller.isSubmitting, isTrue);
      retry.complete();
      expect(await second, isA<SubmissionSuccess<void>>());
      expect(observed, [true, false, true, false]);
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

      expect(await duplicate, isA<SubmissionIgnored<void>>());
      expect(calls, equals(1));
      expect(controller.isSubmitting, isTrue);
      expect(observed, [true]);
      pending.complete();
      expect(await first, isA<SubmissionSuccess<void>>());
      expect(calls, equals(1));
    });

    test('handles a synchronous exception from persistence', () async {
      addTearDown(controller.dispose);

      final saved = await controller.submit<void>(() => throw Exception('Cannot save'));

      expect(saved, isA<SubmissionFailure<void>>());
      expect(controller.isSubmitting, isFalse);
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

          expect(
            await result,
            fails ? isA<SubmissionFailure<void>>() : isA<SubmissionSuccess<void>>(),
          );
          expect(observed, isEmpty);
          var called = false;
          final saved = await controller.submit(() async => called = true);
          expect(saved, isA<SubmissionIgnored<bool>>());
          expect(called, isFalse);
        },
      );
    }
  });
}
