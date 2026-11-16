import 'package:shared/time.dart';

DateTime? parseDate(Object? value, {Clock clock = systemClock, int maxDaysInFuture = 30}) {
  final date = tryParseDate(value);
  if (date == null) return null;
  final now = clock();
  final latest = DateTime(now.year, now.month, now.day + maxDaysInFuture);
  return date.isAfter(latest) ? null : date;
}
