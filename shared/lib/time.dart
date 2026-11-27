library;

import 'dart:async';

typedef Delayed<T> = Future<T> Function(Duration, [FutureOr<T> Function()? computation]);
typedef Now = DateTime Function();

final class CalendarDate implements Comparable<CalendarDate> {
  factory(int year, [int month = 1, int day = 1]) {
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError('Invalid calendar date: $year-$month-$day');
    }
    return CalendarDate._(date);
  }

  factory fromDateTime(DateTime value) => CalendarDate(value.year, value.month, value.day);

  factory today({Now now = DateTime.now}) => CalendarDate.fromDateTime(now());

  const new _(this._utcDate);

  final DateTime _utcDate;

  int get year => _utcDate.year;
  int get month => _utcDate.month;
  int get day => _utcDate.day;

  static CalendarDate? tryParse(Object? value) {
    if (value is! String) return null;
    final date = DateTime.tryParse('${value}T00:00:00Z');
    if (date == null) return null;
    final result = CalendarDate._(date);
    return result.toIsoDateString() == value ? result : null;
  }

  CalendarDate addDays(int days) => CalendarDate._(_utcDate.add(Duration(days: days)));

  DateTime toLocalDateTime() => DateTime(year, month, day);

  DateTime toDateTime() => _utcDate;

  String toIsoDateString() => _utcDate.toIso8601String().split('T').first;

  @override
  int compareTo(CalendarDate other) => _utcDate.compareTo(other._utcDate);

  bool operator <(CalendarDate other) => compareTo(other) < 0;

  bool operator <=(CalendarDate other) => compareTo(other) <= 0;

  bool operator >(CalendarDate other) => compareTo(other) > 0;

  bool operator >=(CalendarDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is CalendarDate && _utcDate == other._utcDate;

  @override
  int get hashCode => _utcDate.hashCode;

  @override
  String toString() => toIsoDateString();
}

class const Age(final int years, final int months) {
  factory between(CalendarDate start, CalendarDate end) {
    const monthsInYear = 12;
    final months = (end.year - start.year) * monthsInYear + (end.month - start.month);
    return Age(months ~/ monthsInYear, months.remainder(monthsInYear));
  }
}
