import 'package:shared/model.dart';
import 'package:shared/time.dart';

enum ScheduleMetric { odometer, date }

class const ScheduleAlert(final String name, final ScheduleMetric metric, final int remaining) {
  bool get isOverdue => remaining < 0;

  int _compareTo(ScheduleAlert other) {
    if (isOverdue != other.isOverdue) return isOverdue ? -1 : 1;
    final byMetric = metric.index.compareTo(other.metric.index);
    if (byMetric != 0) return byMetric;
    final byRemaining = remaining.compareTo(other.remaining);
    return byRemaining == 0 ? name.compareTo(other.name) : byRemaining;
  }
}

List<ScheduleAlert> scheduleAlerts(
  Iterable<Schedule> schedules, {
  required CalendarDate today,
  required int? odometer,
}) {
  final alerts = <ScheduleAlert>[];
  for (final schedule in schedules) {
    final alert = _alertFor(schedule, today, odometer);
    if (alert != null) alerts.add(alert);
  }
  alerts.sort((first, second) => first._compareTo(second));
  return List.unmodifiable(alerts);
}

ScheduleAlert? _alertFor(Schedule schedule, CalendarDate today, int? odometer) {
  const dueSoonDays = 30;
  const dueSoonDistance = 500;
  final due = schedule.nextDue;
  if (schedule.isArchived || due == null) return null;

  final dueOdometer = due.odometer;
  final dueDate = due.date;
  final distance = dueOdometer == null || odometer == null ? null : dueOdometer - odometer;
  final days = dueDate?.toDateTime().difference(today.toDateTime()).inDays;
  if (distance != null && distance < 0) {
    return ScheduleAlert(schedule.name, .odometer, distance);
  }
  if (days != null && days < 0) return ScheduleAlert(schedule.name, .date, days);
  if (distance != null && distance < dueSoonDistance) {
    return ScheduleAlert(schedule.name, .odometer, distance);
  }
  if (days != null && days < dueSoonDays) return ScheduleAlert(schedule.name, .date, days);
  return null;
}
