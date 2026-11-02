import 'package:server/src/validation/date.dart';
import 'package:test/test.dart';

void main() {
  test('vehicle dates use the calendar components of the clock', () {
    final now = DateTime(2026, 11, 1, 23, 30);
    expect(parseDate('2026-11-01', clock: () => now), DateTime(2026, 11, 1));
    expect(parseDate('2026-11-02', clock: () => now), isNull);
  });

  test('the seven-day allowance uses calendar days across month boundaries', () {
    final now = DateTime(2026, 10, 28, 23, 30);
    expect(parseDate('2026-11-04', clock: () => now, maxDaysInFuture: 7), DateTime(2026, 11, 4));
    expect(parseDate('2026-11-05', clock: () => now, maxDaysInFuture: 7), isNull);
  });
}
