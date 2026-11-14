import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/ui/list_view_model.dart';
import 'package:tw_app/ui/schedules/schedule_autocomplete_item.dart';
import 'package:tw_app/ui/schedules/schedule_summary.dart';
import 'package:tw_app/app/operation_repo.dart';
import 'package:tw_app/app/repository_provider.dart';
import 'package:tw_app/app/vehicle_service.dart';
import 'package:tw_app/ui/form/form_submission_controller.dart';

class const OperationFormScreen({super.key, required final VehicleService vehicleService})
    extends StatefulWidget {
  static const nameFieldKey = ValueKey('operation-name-field');
  static const detailsFieldKey = ValueKey('operation-details-field');
  static const saveButtonKey = ValueKey('operation-save-button');
  static const errorSnackBarKey = ValueKey('operation-save-error-snackbar');
  static const suggestionsLoadingKey = ValueKey('operation-suggestions-loading');
  static const suggestionsErrorKey = ValueKey('operation-suggestions-error');
  static const suggestionsRetryKey = ValueKey('operation-suggestions-retry');

  @override
  State<OperationFormScreen> createState() => _OperationFormScreenState();
}

class _OperationFormScreenState extends State<OperationFormScreen> {
  late final OperationRepo _repo = RepositoryProvider.read(context).operationRepo;
  late final ScheduleRepo _scheduleRepo;
  late final ListViewModel<Schedule> _schedules;
  late Future<void> _scheduleLoad;
  late final _changes = Listenable.merge([_submission, _schedules]);
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _nameFocus = FocusNode();
  Schedule? _selectedSchedule;
  final _formKey = GlobalKey<FormState>();
  final _submission = FormSubmissionController();
  var _name = '';
  var _details = '';

  @override
  void initState() {
    super.initState();
    _scheduleRepo = RepositoryProvider.read(context).scheduleRepo;
    _schedules = ListViewModel<Schedule>(
      fetch: () => _scheduleRepo.list(widget.vehicleService.vehicle.id),
    );
    _scheduleLoad = _schedules.load();
  }

  @override
  void dispose() {
    _schedules.dispose();
    _submission.dispose();
    _nameController.dispose();
    _detailsController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('New Operation')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Text(
                widget.vehicleService.vehicle.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                MaterialLocalizations.of(context)
                    .formatShortDate(widget.vehicleService.service.date),
              ),
              const SizedBox(height: 12),
              if (_schedules.isLoading)
                const LinearProgressIndicator(key: OperationFormScreen.suggestionsLoadingKey),
              if (_schedules.hasError)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Schedule suggestions unavailable. You can still enter custom work.',
                        key: OperationFormScreen.suggestionsErrorKey,
                      ),
                    ),
                    TextButton(
                      key: OperationFormScreen.suggestionsRetryKey,
                      onPressed: _submission.isSubmitting ? null : _retrySchedules,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Autocomplete<Schedule>(
                textEditingController: _nameController,
                focusNode: _nameFocus,
                displayStringForOption: (schedule) => schedule.name,
                optionsBuilder: _scheduleOptions,
                optionsViewBuilder: _buildScheduleOptions,
                onSelected: _selectSchedule,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                    TextFormField(
                      key: OperationFormScreen.nameFieldKey,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !_submission.isSubmitting,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Please name the operation'
                          : null,
                      onSaved: (value) => _name = value!.trim(),
                      onChanged: _nameChanged,
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        helperText: _selectedSchedule == null
                            ? 'Choose a schedule or enter custom work'
                            : 'Linked to schedule. Edit the name for custom work.',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                    ),
              ),
              if (_selectedSchedule != null)
                ScheduleSummary(
                  schedule: _selectedSchedule!,
                  distanceUnit: widget.vehicleService.vehicle.distanceUnit,
                ),
              TextFormField(
                key: OperationFormScreen.detailsFieldKey,
                controller: _detailsController,
                enabled: !_submission.isSubmitting,
                onSaved: (value) => _details = value?.trim() ?? '',
                decoration: const InputDecoration(labelText: 'Details (optional)'),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: OperationFormScreen.saveButtonKey,
                onPressed: _submission.isSubmitting ? null : _saveForm,
                child: Text(_submission.isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildScheduleOptions(
    BuildContext context,
    AutocompleteOnSelected<Schedule> onSelected,
    Iterable<Schedule> options,
  ) {
    final highlightedIndex = AutocompleteHighlightedOption.of(context);
    return Material(
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, schedule) in options.indexed)
                ScheduleAutocompleteItem(
                  schedule: schedule,
                  distanceUnit: widget.vehicleService.vehicle.distanceUnit,
                  highlighted: index == highlightedIndex,
                  onTap: () => onSelected(schedule),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveForm() async {
    if (_submission.isSubmitting) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    _nameFocus.unfocus();
    final saved = await _submission.submit(_persistOperation);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (_submission.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: OperationFormScreen.errorSnackBarKey,
            content: Text('Save failed. Please try again.'),
          ),
        );
    }
  }

  Future<Iterable<Schedule>> _scheduleOptions(TextEditingValue value) async {
    await _scheduleLoad;
    if (!mounted || _submission.isSubmitting || _schedules.hasError) return const [];
    final query = value.text.trim().toLowerCase();
    return _schedules.items.where(
      (schedule) => !schedule.isArchived && schedule.name.toLowerCase().contains(query),
    );
  }

  void _retrySchedules() {
    _nameFocus.unfocus();
    _scheduleLoad = _schedules.load();
  }

  void _selectSchedule(Schedule schedule) {
    if (_submission.isSubmitting) return;
    setState(() {
      _selectedSchedule = schedule;
    });
  }

  void _nameChanged(String value) {
    if (_selectedSchedule != null && value != _selectedSchedule!.name) {
      setState(() => _selectedSchedule = null);
    }
  }

  Future<void> _persistOperation() {
    final schedule = _selectedSchedule;
    if (schedule != null) {
      return _repo.createFromSchedule(
        widget.vehicleService.service.id,
        scheduleId: schedule.id,
        details: _details,
      );
    }
    return _repo.create(widget.vehicleService.service.id, name: _name, details: _details);
  }
}
