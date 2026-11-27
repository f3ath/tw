import 'package:material_ui/material_ui.dart';
import 'package:app/app/vehicle_schedule.dart';
import 'package:app/ui/schedules/schedule_interval.dart';

class const ScheduleSummary({super.key, required final VehicleSchedule vehicleSchedule})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final schedule = vehicleSchedule.schedule;
    final interval = formatScheduleInterval(
      schedule,
      vehicleSchedule.vehicle.mileageUnit,
      MaterialLocalizations.of(context),
    );
    if (interval.isEmpty && schedule.details.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (interval.isNotEmpty) Text(interval),
          if (schedule.details.isNotEmpty) Text(schedule.details),
        ],
      ),
    );
  }
}
