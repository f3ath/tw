import 'package:app/ui/delete_and_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/ui/schedules/schedule_delete_dialog.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/loading_view.dart';
import 'package:app/ui/error_retry_view.dart';
import 'package:app/ui/schedules/schedule_card.dart';
import 'package:app/ui/schedules/schedule_form_screen.dart';

class const ScheduleScreen({super.key, required final Vehicle vehicle}) extends StatefulWidget {
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
          return const LoadingView(indicatorKey: ScheduleScreen.loadingIndicatorKey);
        }
        if (_model.hasError) {
          return ErrorRetryView(
            message: 'Error loading schedules',
            errorTextKey: ScheduleScreen.errorTextKey,
            retryButtonKey: ScheduleScreen.retryButtonKey,
            onRetry: _model.load,
          );
        }
        if (_model.items.isEmpty) {
          return const Center(child: Text('No schedules yet', key: ScheduleScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.items.length,
          itemBuilder: (_, index) => _buildScheduleCard(_model.items[index]),
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
    switch (action) {
      case .edit:
        await _openScheduleForm(schedule: schedule);
        return;
      case .delete:
        await _deleteSchedule(schedule);
        return;
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    final confirmed = await _confirmScheduleDeletion(schedule);
    if (!confirmed || !mounted) return;
    await deleteAndRefresh(
      context: context,
      delete: () => _repo.delete(schedule.id),
      refresh: _model.load,
      errorSnackBarKey: ScheduleScreen.deleteErrorSnackBarKey,
    );
  }

  Future<bool> _confirmScheduleDeletion(Schedule schedule) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) =>
            ScheduleDeleteDialog(key: ScheduleDeleteDialog.confirmationKey, schedule: schedule),
      ) ??
      false;

  Future<void> _openScheduleForm({Schedule? schedule}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormScreen(vehicle: widget.vehicle, schedule: schedule),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }
}
