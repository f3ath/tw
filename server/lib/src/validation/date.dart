import 'package:shared/time.dart';

CalendarDate? parseDate(Object? value, {Now now = DateTime.now, int maxDaysInFuture = 30}) {
  final date = CalendarDate.tryParse(value);
  if (date == null) return null;
  final latest = CalendarDate.today(now: now).addDays(maxDaysInFuture);
  return date > latest ? null : date;
}
