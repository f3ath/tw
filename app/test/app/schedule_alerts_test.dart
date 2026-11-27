import 'package:app/app/schedule_alerts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';

void main() {
  final today = CalendarDate(2026, 10, 31);

  test('ranks alerts by status, then qualifying odometer, then urgency', () {
    final schedules = [
      schedule('Soon by date', date: today.addDays(1)),
      schedule('Overdue by date', date: today.addDays(-10), odometer: 10100),
      schedule('Soon by odometer', date: today.addDays(1), odometer: 10100),
      schedule('Overdue more by odometer', date: today.addDays(-1), odometer: 9500),
      schedule('Overdue less by odometer', odometer: 9800),
      schedule('Sooner by odometer', odometer: 10050),
    ];

    final alerts = scheduleAlerts(schedules, today: today, odometer: 10000);

    expect(alerts.map((alert) => (alert.name, alert.metric, alert.remaining)), [
      ('Overdue more by odometer', ScheduleMetric.odometer, -500),
      ('Overdue less by odometer', ScheduleMetric.odometer, -200),
      ('Overdue by date', ScheduleMetric.date, -10),
      ('Sooner by odometer', ScheduleMetric.odometer, 50),
      ('Soon by odometer', ScheduleMetric.odometer, 100),
      ('Soon by date', ScheduleMetric.date, 1),
    ]);
  });

  test('excludes archived schedules and applies strict due-soon limits', () {
    final schedules = [
      schedule('Due today', date: today),
      schedule('Due now by odometer', odometer: 10000),
      schedule('29 days', date: today.addDays(29)),
      schedule('499 units', odometer: 10499),
      schedule('30 days', date: today.addDays(30)),
      schedule('500 units', odometer: 10500),
      schedule('Archived', odometer: 0, archived: true),
      schedule('No due values'),
    ];

    final alerts = scheduleAlerts(schedules, today: today, odometer: 10000);

    expect(alerts.map((alert) => alert.name), [
      'Due now by odometer',
      '499 units',
      'Due today',
      '29 days',
    ]);
    expect(alerts.every((alert) => !alert.isOverdue), isTrue);
  });

  test('uses only dates when the vehicle has no odometer reading', () {
    final schedules = [
      schedule('Odometer only', odometer: 100),
      schedule('Both', date: today.addDays(3), odometer: 100),
    ];

    final alert = scheduleAlerts(schedules, today: today, odometer: null).single;

    expect((alert.name, alert.metric, alert.remaining), ('Both', ScheduleMetric.date, 3));
  });
}

Schedule schedule(String name, {CalendarDate? date, int? odometer, bool archived = false}) =>
    Schedule(
      id: name,
      vehicleId: 'vehicle-id',
      name: name,
      intervalDistance: odometer == null ? null : 5000,
      intervalMonths: date == null ? null : 6,
      details: '',
      isArchived: archived,
      nextDue: (date: date, odometer: odometer),
    );
