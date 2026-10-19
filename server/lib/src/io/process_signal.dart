import 'dart:async';
import 'dart:io';

/// Returns a Future that completes with the first signal received from the given [signals].
Future<ProcessSignal> firstProcessSignal(Iterable<ProcessSignal> signals) {
  final completer = Completer<ProcessSignal>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];

  for (final signal in signals) {
    subscriptions.add(
      signal.watch().listen((it) {
        if (completer.isCompleted) return;
        completer.complete(it);
        for (final sub in subscriptions) {
          sub.cancel();
        }
      }),
    );
  }

  return completer.future;
}
