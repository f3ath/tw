import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:app/ui/schedules/schedule_interval.dart';

class const ScheduleCard({
  super.key,
  required final Schedule schedule,
  required final MileageUnit mileageUnit,
  required final ValueChanged<ScheduleAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String scheduleId) => ValueKey('schedule-menu-$scheduleId');

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final interval = formatScheduleInterval(schedule, mileageUnit, localizations);
    return Card(
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.top,
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
        subtitle: Column(
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
