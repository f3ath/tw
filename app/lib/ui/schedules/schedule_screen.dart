import 'package:app/ui/delete_and_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/list_state_view.dart';
import 'package:app/ui/schedules/schedule_card.dart';
import 'package:app/ui/schedules/schedule_form_screen.dart';

class const ScheduleScreen({
  super.key,
  required final Vehicle vehicle,
  final VoidCallback? onChanged,
}) extends StatefulWidget {
  static const addButtonKey = ValueKey('schedules-add-button');
  static const loadingIndicatorKey = ValueKey('schedules-loading-indicator');
  static const errorTextKey = ValueKey('schedules-error-text');
  static const emptyTextKey = ValueKey('schedules-empty-text');
  static const deleteErrorSnackBarKey = ValueKey('schedule-delete-error-snackbar');
  static const retryButtonKey = ValueKey('schedules-retry-button');
  static ValueKey<String> scheduleKey(String id) => ValueKey('schedule-$id');

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleRepo _repo;
  late final ListViewModel<Schedule> _model;

  @override
  void initState() {
    super.initState();
    _repo = RepositoryProvider.read(context).scheduleRepo;
    _model = ListViewModel<Schedule>(fetch: () => _repo.list(widget.vehicle.id));
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _ScheduleActions(
      context: context,
      vehicle: widget.vehicle,
      delete: _repo.delete,
      reload: _model.load,
      onChanged: widget.onChanged,
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.event_repeat, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.vehicle.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListStateView<Schedule>(
        model: _model,
        loadingIndicatorKey: ScheduleScreen.loadingIndicatorKey,
        errorTextKey: ScheduleScreen.errorTextKey,
        retryButtonKey: ScheduleScreen.retryButtonKey,
        emptyTextKey: ScheduleScreen.emptyTextKey,
        errorMessage: 'Error loading schedules',
        emptyMessage: 'No schedules yet',
        itemBuilder: (schedule) => _buildScheduleCard(schedule, actions),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: ScheduleScreen.addButtonKey,
        icon: const Icon(Icons.add),
        label: const Text('New Schedule'),
        onPressed: () => actions.openForm(),
      ),
    );
  }

  ScheduleCard _buildScheduleCard(Schedule schedule, _ScheduleActions actions) => ScheduleCard(
    key: ScheduleScreen.scheduleKey(schedule.id),
    schedule: schedule,
    mileageUnit: widget.vehicle.mileageUnit,
    onAction: (action) => actions.handle(action, schedule),
  );
}

class const _ScheduleActions({
  required final BuildContext context,
  required final Vehicle vehicle,
  required final Future<void> Function(String) delete,
  required final Future<void> Function() reload,
  required final VoidCallback? onChanged,
}) {
  Future<void> handle(ScheduleAction action, Schedule schedule) => switch (action) {
    .edit => openForm(schedule: schedule),
    .delete => _deleteSchedule(schedule),
  };

  Future<void> _deleteSchedule(Schedule schedule) => confirmDeleteAndRefresh(
    context: context,
    title: 'Delete schedule?',
    message: 'Delete "${schedule.name}"? This cannot be undone.',
    delete: () => delete(schedule.id),
    refresh: _reloadAfterChange,
    errorSnackBarKey: ScheduleScreen.deleteErrorSnackBarKey,
  );

  Future<void> openForm({Schedule? schedule}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormScreen(
          vehicle: vehicle,
          schedule: schedule,
          onCreateConflict: _reloadAfterChange,
        ),
      ),
    );
    if (refresh == true && context.mounted) await _reloadAfterChange();
  }

  Future<void> _reloadAfterChange() {
    onChanged?.call();
    return reload();
  }
}
