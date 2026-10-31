import 'dart:async';

import 'package:server/src/server/lifecycle.dart';
import 'package:test/test.dart';

void main() {
  late Lifecycle lifecycle;
  late List<String> calls;
  late Completer<void> startup;
  late Completer<void> shutdown;
  late Completer<void> startEntered;
  late Completer<void> stopEntered;

  setUp(() {
    calls = [];
    startup = Completer<void>();
    shutdown = Completer<void>();
    startEntered = Completer<void>();
    stopEntered = Completer<void>();
    lifecycle = Lifecycle(
      onStart: () {
        calls.add('start');
        if (!startEntered.isCompleted) startEntered.complete();
        return startup.future;
      },
      onStop: () {
        calls.add('stop');
        if (!stopEntered.isCompleted) stopEntered.complete();
        return shutdown.future;
      },
    );
  });

  test('stop before start is a no-op', () async {
    await lifecycle.stop();
    expect(calls, isEmpty);
  });

  test('concurrent starts share a future and repeated starts are no-ops', () async {
    final first = lifecycle.start();
    expect(lifecycle.start(), same(first));
    await startEntered.future;
    expect(calls, ['start']);
    startup.complete();
    await first;
    await lifecycle.start();
    expect(calls, ['start']);
  });

  test('concurrent stops share a future and repeated stops are no-ops', () async {
    startup.complete();
    await lifecycle.start();
    final first = lifecycle.stop();
    expect(lifecycle.stop(), same(first));
    await stopEntered.future;
    expect(calls, ['start', 'stop']);
    shutdown.complete();
    await first;
    await lifecycle.stop();
    expect(calls, ['start', 'stop']);
  });

  test('stop waits for pending startup', () async {
    final starting = lifecycle.start();
    await startEntered.future;
    final stopping = lifecycle.stop();
    var stopped = false;
    final observed = stopping.then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['start']);
    expect(stopped, isFalse);
    startup.complete();
    await starting;
    await stopEntered.future;
    expect(calls, ['start', 'stop']);
    expect(stopped, isFalse);
    shutdown.complete();
    await observed;
    expect(stopped, isTrue);
  });

  test('starts during shutdown wait and share one new startup', () async {
    startup.complete();
    await lifecycle.start();
    final stopping = lifecycle.stop();
    await stopEntered.future;
    startup = Completer<void>();
    final first = lifecycle.start();
    final second = lifecycle.start();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['start', 'stop']);
    shutdown.complete();
    await stopping;
    // Drain queued continuations before completing the new startup.
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['start', 'stop', 'start']);
    startup.complete();
    await Future.wait([first, second]);
  });

  test('startup failure reaches callers and allows retry', () async {
    final error = StateError('startup failed');
    final starting = lifecycle.start();
    final first = expectLater(starting, throwsA(same(error)));
    final second = expectLater(lifecycle.start(), throwsA(same(error)));
    await startEntered.future;
    startup.completeError(error);
    await Future.wait([first, second]);
    startup = Completer<void>()..complete();
    await lifecycle.start();
    expect(calls, ['start', 'start']);
  });

  test('stop waits for failed startup without calling shutdown', () async {
    final error = StateError('startup failed');
    final starting = expectLater(lifecycle.start(), throwsA(same(error)));
    await startEntered.future;
    final stopping = lifecycle.stop();
    startup.completeError(error);
    await Future.wait([starting, stopping]);
    expect(calls, ['start']);
    startup = Completer<void>()..complete();
    await lifecycle.start();
    expect(calls, ['start', 'start']);
  });

  test('shutdown failure reaches waiting starts and permits shutdown retry', () async {
    startup.complete();
    await lifecycle.start();
    final error = StateError('shutdown failed');
    final stopping = expectLater(lifecycle.stop(), throwsA(same(error)));
    final restarting = expectLater(lifecycle.start(), throwsA(same(error)));
    await stopEntered.future;
    shutdown.completeError(error);
    await Future.wait([stopping, restarting]);
    expect(calls, ['start', 'stop']);
    shutdown = Completer<void>()..complete();
    await lifecycle.stop();
    expect(calls, ['start', 'stop', 'stop']);
    await lifecycle.start();
    expect(calls, ['start', 'stop', 'stop', 'start']);
  });

  test('synchronous callback failures become future errors and permit retry', () async {
    final error = StateError('synchronous failure');
    var attempts = 0;
    final subject = Lifecycle(
      onStart: () {
        if (attempts++ == 0) throw error;
        return Future<void>.value();
      },
      onStop: () => throw error,
    );
    await expectLater(subject.start(), throwsA(same(error)));
    await subject.start();
    await expectLater(subject.stop(), throwsA(same(error)));
    await expectLater(subject.stop(), throwsA(same(error)));
  });
}
