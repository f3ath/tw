import 'package:material_ui/material_ui.dart';
import 'package:app/ui/form/form_submission_controller.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/app/schedule_repo.dart';

class const ScheduleFormScreen({
  super.key,
  required final Vehicle vehicle,
  final Schedule? schedule,
}) extends StatefulWidget {
  static const nameFieldKey = ValueKey('schedule-name-field');
  static const distanceFieldKey = ValueKey('schedule-distance-field');
  static const monthsFieldKey = ValueKey('schedule-months-field');
  static const detailsFieldKey = ValueKey('schedule-details-field');
  static const saveButtonKey = ValueKey('schedule-save-button');

  static const errorSnackBarKey = ValueKey('schedule-save-error-snackbar');

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  late final ScheduleRepo _repo = RepositoryProvider.read(context).scheduleRepo;
  final _formKey = GlobalKey<FormState>();
  late final _distanceController = TextEditingController(
    text: widget.schedule?.intervalDistance?.toString(),
  );
  late final _monthsController = TextEditingController(
    text: widget.schedule?.intervalMonths?.toString(),
  );
  int? _intervalDistance;
  int? _intervalMonths;
  var _name = '';
  var _details = '';
  final _submission = FormSubmissionController();

  bool get _hasInterval =>
      _distanceController.text.trim().isNotEmpty || _monthsController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _submission.dispose();
    _distanceController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _submission,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(widget.schedule == null ? 'New Schedule' : 'Edit Schedule')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Text(widget.vehicle.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                key: ScheduleFormScreen.nameFieldKey,
                initialValue: widget.schedule?.name,
                enabled: !_submission.isSubmitting,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Please name the schedule' : null,
                onSaved: (value) => _name = value!.trim(),
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const Text('Repeat by distance, time, or both.'),
              TextFormField(
                key: ScheduleFormScreen.distanceFieldKey,
                controller: _distanceController,
                onSaved: (value) => _intervalDistance = int.tryParse(value?.trim() ?? ''),
                enabled: !_submission.isSubmitting,
                validator: _validateInterval,
                decoration: InputDecoration(
                  labelText: 'Distance interval',
                  suffixText: widget.vehicle.distanceUnit.name,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                key: ScheduleFormScreen.monthsFieldKey,
                controller: _monthsController,
                onSaved: (value) => _intervalMonths = int.tryParse(value?.trim() ?? ''),
                enabled: !_submission.isSubmitting,
                validator: _validateInterval,
                decoration: const InputDecoration(labelText: 'Time interval', suffixText: 'months'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                key: ScheduleFormScreen.detailsFieldKey,
                initialValue: widget.schedule?.details,
                enabled: !_submission.isSubmitting,
                onSaved: (value) => _details = value?.trim() ?? '',
                decoration: const InputDecoration(labelText: 'Details (optional)'),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: ScheduleFormScreen.saveButtonKey,
                onPressed: _submission.isSubmitting ? null : _saveForm,
                child: Text(_submission.isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String? _validateInterval(String? value) =>
      _hasInterval ? _validateOptionalInterval(value) : 'Enter a distance or time interval';

  Future<void> _saveForm() async {
    if (_submission.isSubmitting) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    final saved = await _submission.submit(_persistSchedule);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (_submission.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: ScheduleFormScreen.errorSnackBarKey,
            content: Text('Save failed. Please try again.'),
          ),
        );
    }
  }

  Future<void> _persistSchedule() async {
    final schedule = widget.schedule;
    if (schedule == null) {
      await _repo.create(
        widget.vehicle.id,
        name: _name,
        intervalDistance: _intervalDistance,
        intervalMonths: _intervalMonths,
        details: _details,
      );
    } else {
      await _repo.update(
        schedule.id,
        name: _name,
        intervalDistance: _intervalDistance,
        intervalMonths: _intervalMonths,
        details: _details,
      );
    }
  }
}

String? _validateOptionalInterval(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final interval = int.tryParse(text);
  return interval == null || interval <= 0 ? 'Enter a positive whole number' : null;
}
