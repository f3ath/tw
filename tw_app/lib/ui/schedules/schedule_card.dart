import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ScheduleCard({
  super.key,
  required final Schedule schedule,
  required final DistanceUnit distanceUnit,
}) extends StatelessWidget {
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
