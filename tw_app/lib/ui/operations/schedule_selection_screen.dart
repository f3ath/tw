import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/operation_repo.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:tw_app/ui/error_retry_view.dart';
import 'package:tw_app/ui/form/form_submission_controller.dart';
import 'package:tw_app/ui/list_view_model.dart';
import 'package:tw_app/ui/loading_view.dart';

class const ScheduleSelectionScreen({super.key, required final VehicleService vehicleService})
    extends StatefulWidget {
  static const loadingIndicatorKey = ValueKey('schedule-selection-loading-indicator');
  static const errorTextKey = ValueKey('schedule-selection-error-text');
  static const retryButtonKey = ValueKey('schedule-selection-retry-button');
  static const emptyTextKey = ValueKey('schedule-selection-empty-text');
  static const savingIndicatorKey = ValueKey('schedule-selection-saving-indicator');
  static const errorSnackBarKey = ValueKey('schedule-selection-save-error-snackbar');
  static ValueKey<String> scheduleKey(String id) => ValueKey('schedule-selection-$id');

  @override
  State<ScheduleSelectionScreen> createState() => _ScheduleSelectionScreenState();
}

class _ScheduleSelectionScreenState extends State<ScheduleSelectionScreen> {
  late final ScheduleRepo _scheduleRepo;
  late final OperationRepo _operationRepo;
  late final ListViewModel<Schedule> _model;
  final _submission = FormSubmissionController();
  late final _changes = Listenable.merge([_model, _submission]);

  @override
  void initState() {
    super.initState();
    final repositories = RepositoryProvider.read(context);
    _scheduleRepo = repositories.scheduleRepo;
    _operationRepo = repositories.operationRepo;
    _model = ListViewModel<Schedule>(fetch: _loadSchedules);
    _model.load();
  }

  Future<List<Schedule>> _loadSchedules() async {
    final schedules = await _scheduleRepo.list(widget.vehicleService.vehicle.id);
    return schedules.where((schedule) => !schedule.isArchived).toList();
  }

  @override
  void dispose() {
    _model.dispose();
    _submission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Select Schedule')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    widget.vehicleService.vehicle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    MaterialLocalizations.of(context)
                        .formatShortDate(widget.vehicleService.service.date),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSchedules()),
            if (_submission.isSubmitting)
              const LinearProgressIndicator(key: ScheduleSelectionScreen.savingIndicatorKey),
          ],
        ),
      ),
    ),
  );

  Widget _buildSchedules() {
    if (_model.isLoading) {
      return const LoadingView(indicatorKey: ScheduleSelectionScreen.loadingIndicatorKey);
    }
    if (_model.hasError) {
      return ErrorRetryView(
        message: 'Error loading schedules',
        errorTextKey: ScheduleSelectionScreen.errorTextKey,
        retryButtonKey: ScheduleSelectionScreen.retryButtonKey,
        onRetry: _model.load,
      );
    }
    if (_model.items.isEmpty) {
      return const Center(
        child: Text('No schedules available', key: ScheduleSelectionScreen.emptyTextKey),
      );
    }
    return ListView.builder(
      itemCount: _model.items.length,
      itemBuilder: (_, index) {
        final schedule = _model.items[index];
        return Card(
          key: ScheduleSelectionScreen.scheduleKey(schedule.id),
          child: ListTile(
            title: Text(schedule.name),
            subtitle: schedule.details.isEmpty ? null : Text(schedule.details),
            enabled: !_submission.isSubmitting,
            onTap: _submission.isSubmitting ? null : () => _selectSchedule(schedule),
          ),
        );
      },
    );
  }

  Future<void> _selectSchedule(Schedule schedule) async {
    if (_submission.isSubmitting) return;
    final saved = await _submission.submit(
      () => _operationRepo.createFromSchedule(
        widget.vehicleService.service.id,
        scheduleId: schedule.id,
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (_submission.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: ScheduleSelectionScreen.errorSnackBarKey,
            content: Text('Save failed. Please try again.'),
          ),
        );
    }
  }
}
