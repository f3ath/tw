library;

/// Returns current UTC datetime
typedef Clock = DateTime Function();

/// Default implementation reads system time
DateTime systemClock() => DateTime.now().toUtc();

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime? tryParseDate(Object? value) {
  if (value is! String) return null;
  final date = DateTime.tryParse(value);
  if (date == null || date.toIso8601String().split('T').first != value) return null;
  return date;
}
