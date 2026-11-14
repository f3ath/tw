import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/schedules_repo.dart';
import 'package:tw_app/testing/stub.dart';
import 'package:tw_app/ui/schedules/schedule_view_model.dart';
import 'package:tw_app/testing/samples.dart' as samples;

class const ScheduleScreen({
  super.key,
  required final Vehicle vehicle,
  required final SchedulesRepo repo,
}) extends StatefulWidget {
  static const retryButtonKey = ValueKey('schedules-retry-button');
  static ValueKey<String> scheduleKey(String id) => ValueKey('schedule-$id');

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleViewModel _model;

  @override
  void initState() {
    super.initState();
    _model = ScheduleViewModel(repo: widget.repo, vehicleId: widget.vehicle.id);
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const Icon(Icons.event_repeat, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.vehicle.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: _model,
      builder: (_, _) {
        if (_model.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              mainAxisSize: .min,
              children: [
                const Text('Error loading schedules'),
                FilledButton(
                  key: ScheduleScreen.retryButtonKey,
                  onPressed: _model.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (_model.schedules.isEmpty) {
          return const Center(child: Text('No schedules yet'));
        }
        return ListView.builder(
          itemCount: _model.schedules.length,
          itemBuilder: (_, index) {
            final schedule = _model.schedules[index];
            return ListTile(
              key: ScheduleScreen.scheduleKey(schedule.id),
              title: Text(schedule.name),
              subtitle: schedule.details.isEmpty ? null : Text(schedule.details),
            );
          },
        );
      },
    ),
  );
}

@Preview(name: 'Schedules', size: Size(390, 844))
Widget scheduleScreenPreview() => MaterialApp(
  home: ScheduleScreen(
    vehicle: samples.santaFe,
    repo: InMemorySchedulesRepo(initialSchedules: samples.sampleSchedules),
  ),
);
