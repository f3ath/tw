import 'package:app/app/repository_provider.dart';
import 'package:app/app/schedule_alerts.dart';
import 'package:app/ui/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';

class const VehicleDueSchedules({
  super.key,
  required final Vehicle vehicle,
  required final CalendarDate asOf,
}) extends StatefulWidget {
  @override
  State<VehicleDueSchedules> createState() => _VehicleDueSchedulesState();
}

class _VehicleDueSchedulesState extends State<VehicleDueSchedules> {
  late Future<List<Schedule>> _schedules;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    _schedules = RepositoryProvider.read(context).scheduleRepo.list(widget.vehicle.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Schedule>>(
    future: _schedules,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(_loadSchedules),
          child: const Text('Retry due schedules'),
        );
      }
      final alerts = scheduleAlerts(
        snapshot.data ?? const [],
        today: widget.asOf,
        odometer: widget.vehicle.odometer?.value,
      );
      if (alerts.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final alert in alerts) _label(context, alert)],
        ),
      );
    },
  );

  Widget _label(BuildContext context, ScheduleAlert alert) {
    final amount = alert.remaining.abs();
    final value = switch (alert.metric) {
      .odometer =>
        '${MaterialLocalizations.of(context).formatDecimal(amount)} ${widget.vehicle.mileageUnit.name}',
      .date => '$amount ${amount == 1 ? 'day' : 'days'}',
    };
    final status = alert.isOverdue ? 'overdue by' : 'due in';
    final (:fill, :label) = AppColors.scheduleStatus(
      Theme.of(context).colorScheme,
      overdue: alert.isOverdue,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Text('${alert.name} — $status $value', style: TextStyle(color: label)),
      ),
    );
  }
}
