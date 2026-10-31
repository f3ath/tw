import 'dart:async';

/// Returns a Future that completes with the first event received from the given [streams].
Future<T> firstEvent<T>(Iterable<Stream<T>> streams) {
  final completer = Completer<T>();
  final subscriptions = <StreamSubscription<T>>[];

  void completeAndCancelSubscriptions(T event) {
    if (completer.isCompleted) return;
    completer.complete(event);
    for (final sub in subscriptions) {
      sub.cancel();
    }
  }

  subscriptions.addAll(streams.map((it) => it.listen(completeAndCancelSubscriptions)));

  return completer.future;
}
