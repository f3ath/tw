import 'dart:async';

class const Clock() {
  DateTime now() => DateTime.now();

  Future<T> delayed<T>(Duration duration, [FutureOr<T> Function()? computation]) =>
      Future.delayed(duration, computation);
}
