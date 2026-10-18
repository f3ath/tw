import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:tw_server/src/job/periodic_job.dart';
import 'package:tw_server/src/log/log.dart';

void main() {
  test('runs at the configured interval and stops cleanly', () {
    fakeAsync((async) {
      var runs = 0;
      final job = PeriodicJob(() async {
        runs++;
      }, interval: const Duration(minutes: 1));
      job.start();
      job.start();
      async.elapse(const Duration(seconds: 59));
      expect(runs, 0);
      async.elapse(const Duration(seconds: 1));
      expect(runs, 1);
      async.elapse(const Duration(minutes: 1));
      expect(runs, 2);
      unawaited(job.stop());
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(runs, 2);
    });
  });

  test('does not overlap runs and shutdown waits for the active run', () {
    fakeAsync((async) {
      final pending = Completer<void>();
      var runs = 0;
      final job = PeriodicJob(() {
        runs++;
        return pending.future;
      }, interval: const Duration(seconds: 1));
      job.start();
      async.elapse(const Duration(seconds: 3));
      expect(runs, 1);
      var stopped = false;
      unawaited(
        job.stop().then((_) {
          stopped = true;
        }),
      );
      async.flushMicrotasks();
      expect(stopped, isFalse);
      pending.complete();
      async.flushMicrotasks();
      expect(stopped, isTrue);
      async.elapse(const Duration(seconds: 3));
      expect(runs, 1);
    });
  });

  test('logs failures and retries on the next tick', () {
    fakeAsync((async) {
      final log = InMemoryLog();
      var runs = 0;
      final failure = StateError('database unavailable');
      final job = PeriodicJob(
        () async {
          if (++runs == 1) throw failure;
        },
        interval: const Duration(seconds: 1),
        log: log,
      );
      job.start();
      async.elapse(const Duration(seconds: 2));
      expect(runs, 2);
      expect(log.records.single.error, same(failure));
      unawaited(job.stop());
      async.flushMicrotasks();
    });
  });
}
