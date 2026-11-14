import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/schedules_repo.dart';
import 'package:tw_app/ui/schedules/schedule_view_model.dart';
import 'package:tw_app/ui/schedules/schedule_card.dart';
import 'package:tw_app/ui/schedules/schedule_form_screen.dart';

class const ScheduleScreen({
  super.key,
  required final Vehicle vehicle,
  required final SchedulesRepo repo,
}) extends StatefulWidget {
  static const addButtonKey = ValueKey('schedules-add-button');
  static const loadingIndicatorKey = ValueKey('schedules-loading-indicator');
  static const errorTextKey = ValueKey('schedules-error-text');
  static const emptyTextKey = ValueKey('schedules-empty-text');
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
          return const Center(
            child: CircularProgressIndicator(key: ScheduleScreen.loadingIndicatorKey),
          );
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              mainAxisSize: .min,
              children: [
                const Text('Error loading schedules', key: ScheduleScreen.errorTextKey),
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
          return const Center(child: Text('No schedules yet', key: ScheduleScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.schedules.length,
          itemBuilder: (_, index) => _buildScheduleCard(_model.schedules[index]),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: ScheduleScreen.addButtonKey,
      icon: const Icon(Icons.add),
      label: const Text('New Schedule'),
      onPressed: () => _openScheduleForm(),
    ),
  );

  ScheduleCard _buildScheduleCard(Schedule schedule) => ScheduleCard(
    key: ScheduleScreen.scheduleKey(schedule.id),
    schedule: schedule,
    distanceUnit: widget.vehicle.distanceUnit,
    onAction: (action) => _handleScheduleAction(action, schedule),
  );

  Future<void> _handleScheduleAction(ScheduleAction action, Schedule schedule) async {
    if (action == .edit) {
      await _openScheduleForm(schedule: schedule);
    }
  }

  Future<void> _openScheduleForm({Schedule? schedule}) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScheduleFormScreen(vehicle: widget.vehicle, schedule: schedule),
    ),
  );
}
