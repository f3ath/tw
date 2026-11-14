import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

String formatScheduleInterval(
  Schedule schedule,
  DistanceUnit unit,
  MaterialLocalizations localizations,
) {
  final distance = schedule.intervalDistance;
  final months = schedule.intervalMonths;
  final intervals = [
    if (distance != null) '${localizations.formatDecimal(distance)} ${unit.name}',
    if (months != null) '$months mo',
  ];
  return intervals.isEmpty ? '' : 'Every ${intervals.join(' / ')}';
}
