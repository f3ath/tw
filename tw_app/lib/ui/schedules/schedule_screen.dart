import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/ui/schedules/schedule_view_model.dart';
import 'package:tw_app/ui/schedules/schedule_card.dart';
import 'package:tw_app/ui/schedules/schedule_form_screen.dart';

class const ScheduleScreen({
  super.key,
  required final Vehicle vehicle,
  required final ScheduleRepo repo,
}) extends StatefulWidget {
  static const addButtonKey = ValueKey('schedules-add-button');
  static const loadingIndicatorKey = ValueKey('schedules-loading-indicator');
  static const errorTextKey = ValueKey('schedules-error-text');
  static const emptyTextKey = ValueKey('schedules-empty-text');
  static const deleteErrorSnackBarKey = ValueKey('schedule-delete-error-snackbar');
  static const deleteConfirmation = ValueKey('schedule-delete-confirmation');
  static const deleteButton = ValueKey('schedule-delete-confirmation-delete');
  static const cancelButton = ValueKey('schedule-delete-confirmation-cancel');
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
    try {
      await widget.repo.delete(schedule.id);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: ScheduleScreen.deleteErrorSnackBarKey,
              content: Text('Could not confirm deletion. Refreshing...'),
            ),
          );
      }
    }
    if (mounted) await _model.load();
  }

  Future<bool> _confirmScheduleDeletion(Schedule schedule) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: ScheduleScreen.deleteConfirmation,
          title: const Text('Delete schedule?'),
          content: Text('Delete "${schedule.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              key: ScheduleScreen.cancelButton,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: ScheduleScreen.deleteButton,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openScheduleForm({Schedule? schedule}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ScheduleFormScreen(vehicle: widget.vehicle, repo: widget.repo, schedule: schedule),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }
}
