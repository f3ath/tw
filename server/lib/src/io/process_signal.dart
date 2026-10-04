import 'dart:async';
import 'dart:io';

/// Returns a Future that completes with the first signal received from the given [signals].
Future<ProcessSignal> firstProcessSignal(Iterable<ProcessSignal> signals) {
  final completer = Completer<ProcessSignal>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];

  void complete(ProcessSignal signal) {
    if (completer.isCompleted) return;
    completer.complete(signal);
    for (final subscription in subscriptions) subscription.cancel();
  }

  for (final signal in signals) {
    subscriptions.add(signal.watch().listen(complete));
  }

  return completer.future;
}
