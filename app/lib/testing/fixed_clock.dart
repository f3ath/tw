import 'package:app/time/clock.dart';

class const FixedClock(final DateTime _now) extends Clock {
  @override
  DateTime now() => _now;
}
