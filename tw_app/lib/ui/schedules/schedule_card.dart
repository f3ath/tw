import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ScheduleCard({
  super.key,
  required final Schedule schedule,
  required final DistanceUnit distanceUnit,
  required final ValueChanged<ScheduleAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String scheduleId) => ValueKey('schedule-menu-$scheduleId');

  @override
  Widget build(BuildContext context) {
    final interval = _formatInterval(schedule, distanceUnit, MaterialLocalizations.of(context));
    return Card(
      child: ListTile(
        title: Text(schedule.name),
        trailing: PopupMenuButton<ScheduleAction>(
          key: ScheduleCard.menuKey(schedule.id),
          tooltip: 'Manage ${schedule.name}',
          icon: const Icon(Icons.more_vert),
          onSelected: onAction,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: ScheduleAction.edit,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Edit')),
                ],
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: ScheduleAction.delete,
              enabled: false,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Delete')),
                ],
              ),
            ),
          ],
        ),
        subtitle: interval.isEmpty && schedule.details.isEmpty
            ? null
            : Column(
                crossAxisAlignment: .start,
                children: [
                  if (interval.isNotEmpty) Text(interval),
                  if (schedule.details.isNotEmpty) Text(schedule.details),
                ],
              ),
      ),
    );
  }
}

enum ScheduleAction { edit, delete }

String _formatInterval(Schedule schedule, DistanceUnit unit, MaterialLocalizations localizations) {
  final distance = schedule.intervalDistance;
  final months = schedule.intervalMonths;
  final intervals = [
    if (distance != null) '${localizations.formatDecimal(distance)} ${unit.name}',
    if (months != null) '$months mo',
  ];
  return intervals.isEmpty ? '' : 'Every ${intervals.join(' / ')}';
}
