import 'package:shared/time.dart';
import 'package:test/test.dart';

void main() {
  test('dates round-trip with value equality and chronological ordering', () {
    final date = CalendarDate(2024, 2, 29);
    final parsed = CalendarDate.tryParse('2024-02-29')!;

    expect(date.toIsoDateString(), '2024-02-29');
    expect(parsed, date);
    expect(parsed.hashCode, date.hashCode);
    expect(date.compareTo(CalendarDate(2024, 3)), lessThan(0));
    expect(date.compareTo(CalendarDate(2024, 2, 28)), greaterThan(0));
  });

  test('comparison operators handle earlier, equal, and later dates', () {
    final earlier = CalendarDate(2024, 2, 29);
    final same = CalendarDate(2024, 2, 29);
    final later = CalendarDate(2024, 3);

    expect(earlier < later, isTrue);
    expect(earlier <= later, isTrue);
    expect(later > earlier, isTrue);
    expect(later >= earlier, isTrue);
    expect(earlier < same, isFalse);
    expect(earlier <= same, isTrue);
    expect(earlier > same, isFalse);
    expect(earlier >= same, isTrue);
  });

  test('rejects invalid calendar components instead of normalizing them', () {
    expect(() => CalendarDate(2025, 2, 29), throwsArgumentError);
    expect(() => CalendarDate(2024, 13), throwsArgumentError);
  });

  test('today uses the calendar date from the injected clock', () {
    final today = CalendarDate.today(now: () => DateTime(2026, 11, 1, 23, 59));

    expect(today, CalendarDate(2026, 11, 1));
  });

  test('conversions preserve the input calendar components', () {
    final date = CalendarDate.fromDateTime(DateTime.utc(2026, 11, 1, 23, 59));

    expect(date, CalendarDate(2026, 11, 1));
    expect(date.toDateTime(), DateTime.utc(2026, 11, 1));
  });

  test('Age.between counts calendar months across years and ignores the day', () {
    final start = CalendarDate(2023, 12, 31);
    final sameMonth = Age.between(start, CalendarDate(2023, 12, 1));
    final nextMonth = Age.between(start, CalendarDate(2024, 1, 1));
    final nextYear = Age.between(start, CalendarDate(2024, 12, 1));
    final earlierMonth = Age.between(start, CalendarDate(2023, 11, 30));

    expect((sameMonth.years, sameMonth.months), (0, 0));
    expect((nextMonth.years, nextMonth.months), (0, 1));
    expect((nextYear.years, nextYear.months), (1, 0));
    expect((earlierMonth.years, earlierMonth.months), (0, -1));
  });
}
