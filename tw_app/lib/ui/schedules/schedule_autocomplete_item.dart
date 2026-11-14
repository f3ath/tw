import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/schedules/schedule_interval.dart';

class const ScheduleAutocompleteItem({
  super.key,
  required final Schedule schedule,
  required final DistanceUnit distanceUnit,
  required final bool highlighted,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Scrollable.ensureVisible(context, alignment: 0.5);
      });
    }
    final interval = formatScheduleInterval(
      schedule,
      distanceUnit,
      MaterialLocalizations.of(context),
    );
    return ListTile(
      title: Text(schedule.name),
      subtitle: interval.isEmpty ? null : Text(interval),
      tileColor: highlighted ? Theme.of(context).focusColor : null,
      onTap: onTap,
    );
  }
}
