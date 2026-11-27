import 'package:app/app/create_conflict.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/ui/form/date_form_field.dart';
import 'package:app/ui/form/form_submission_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:shared/resource_id.dart';
import 'package:shared/time.dart';

class const ServiceFormScreen({
  super.key,
  required final Vehicle vehicle,
  final Service? service,
  final Now now = DateTime.now,
  final VoidCallback? onCreateConflict,
  final VoidCallback? onViewHistory,
}) extends StatefulWidget {
  static const dateFieldKey = ValueKey('service-date-field');
  static const odometerFieldKey = ValueKey('service-odometer-field');
  static const detailsFieldKey = ValueKey('service-details-field');
  static const saveButtonKey = ValueKey('service-save-button');
  static const errorSnackBarKey = ValueKey('service-save-error-snackbar');

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  late final ServiceRepo _repo = RepositoryProvider.read(context).serviceRepo;
  final _formKey = GlobalKey<FormState>();
  late CalendarDate _date;
  late int _odometer;
  var _details = '';
  final _submission = FormSubmissionController();
  late final _draftId = ResourceId.generate();

  @override
  void dispose() {
    _submission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _submission,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(widget.service == null ? 'New Service' : 'Edit Service')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Text(widget.vehicle.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DateFormField(
                key: ServiceFormScreen.dateFieldKey,
                initialValue: widget.service?.date ?? CalendarDate.today(now: widget.now),
                enabled: !_submission.isSubmitting,
                validator: (value) => value == null ? 'Please select a date' : null,
                onSaved: (value) => _date = value!,
                decoration: const InputDecoration(labelText: 'Date'),
                now: widget.now,
              ),
              TextFormField(
                key: ServiceFormScreen.odometerFieldKey,
                initialValue: widget.service?.odometer.toString(),
                enabled: !_submission.isSubmitting,
                validator: (value) {
                  final odometer = int.tryParse(value?.trim() ?? '');
                  return odometer == null || odometer < 0
                      ? 'Enter a nonnegative whole number'
                      : null;
                },
                onSaved: (value) => _odometer = int.parse(value!.trim()),
                decoration: InputDecoration(
                  labelText: 'Odometer',
                  suffixText: widget.vehicle.mileageUnit.name,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                key: ServiceFormScreen.detailsFieldKey,
                initialValue: widget.service?.details,
                enabled: !_submission.isSubmitting,
                onSaved: (value) => _details = value?.trim() ?? '',
                decoration: const InputDecoration(labelText: 'Details (optional)'),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: ServiceFormScreen.saveButtonKey,
                onPressed: _submission.isSubmitting ? null : _saveForm,
                child: Text(_submission.isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _saveForm() async {
    if (_submission.isSubmitting) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    final onCreateConflict = widget.onCreateConflict;
    var hasConflict = false;
    final result = await _submission.submit(() async {
      try {
        return await _persistService();
      } on CreateConflict {
        hasConflict = true;
        rethrow;
      }
    });
    if (hasConflict) onCreateConflict?.call();
    if (!mounted) return;
    switch (result) {
      case SubmissionSuccess(:final value):
        Navigator.of(context).pop(value);
      case SubmissionFailure():
        final onViewHistory = widget.onViewHistory;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: ServiceFormScreen.errorSnackBarKey,
              content: Text(
                hasConflict
                    ? 'This service may already be saved. Check the service history.'
                    : 'Save failed. Please try again.',
              ),
              action: hasConflict && onViewHistory != null
                  ? SnackBarAction(
                      label: 'View history',
                      onPressed: () {
                        if (mounted && ModalRoute.of(context)?.isCurrent == true) onViewHistory();
                      },
                    )
                  : null,
            ),
          );
      case SubmissionIgnored():
        return;
    }
  }

  Future<Service> _persistService() async {
    final service = widget.service;
    if (service == null) {
      return await _repo.create(
        widget.vehicle.id,
        id: _draftId,
        date: _date,
        odometer: _odometer,
        details: _details,
      );
    } else {
      await _repo.update(service.id, date: _date, odometer: _odometer, details: _details);
      return Service(
        service.id,
        vehicleId: service.vehicleId,
        date: _date,
        odometer: _odometer,
        details: _details,
      );
    }
  }
}
