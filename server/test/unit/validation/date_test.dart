import 'package:server/src/validation/date.dart';
import 'package:shared/time.dart';
import 'package:test/test.dart';

void main() {
  test('the seven-day allowance uses calendar days across month boundaries', () {
    DateTime now() => DateTime(2026, 10, 28, 23, 30);
    expect(parseDate('2026-11-04', now: now, maxDaysInFuture: 7), CalendarDate(2026, 11, 4));
    expect(parseDate('2026-11-05', now: now, maxDaysInFuture: 7), isNull);
  });
}
