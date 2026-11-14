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
    final distance = schedule.intervalDistance;
    final months = schedule.intervalMonths;
    final intervals = [
      if (distance != null)
        '${MaterialLocalizations.of(context).formatDecimal(distance)} ${distanceUnit.name}',
      if (months != null) '$months mo',
    ];
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
        subtitle: intervals.isEmpty && schedule.details.isEmpty
            ? null
            : Column(
                crossAxisAlignment: .start,
                children: [
                  if (intervals.isNotEmpty) Text('Every ${intervals.join(' / ')}'),
                  if (schedule.details.isNotEmpty) Text(schedule.details),
                ],
              ),
      ),
    );
  }
}

enum ScheduleAction { edit, delete }
