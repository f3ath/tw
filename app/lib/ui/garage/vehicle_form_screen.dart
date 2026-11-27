import 'package:material_ui/material_ui.dart';
import 'package:app/ui/form/form_submission_controller.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:shared/resource_id.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/app/create_conflict.dart';
import 'package:app/ui/form/date_form_field.dart';
import 'package:shared/time.dart';

class const VehicleFormScreen({
  super.key,
  final Now now = DateTime.now,
  final Vehicle? vehicle,
  final VoidCallback? onCreateConflict,
}) extends StatefulWidget {
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
  static const errorSnackBarKey = ValueKey('vehicle-save-error-snackbar');
  static const nameFieldKey = ValueKey('vehicle-name-field');
  static const mileageUnitFieldKey = ValueKey('vehicle-mileage-unit-field');
  static const dateFieldKey = ValueKey('vehicle-date-field');
  static const saveButtonKey = ValueKey('vehicle-save-button');
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  late final VehicleRepo _repo = RepositoryProvider.read(context).vehicleRepo;
  final _formKey = GlobalKey<FormState>();
  MileageUnit _mileageUnit = .mi;
  CalendarDate? _manufactureDate;
  String _name = '';
  final _submission = FormSubmissionController();
  late final _draftId = ResourceId.generate();

  bool get _isEditing => widget.vehicle != null;

  @override
  void dispose() {
    _submission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _submission,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Vehicle' : 'New Vehicle')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Name'),
                key: VehicleFormScreen.nameFieldKey,
                initialValue: widget.vehicle?.name,
                enabled: !_submission.isSubmitting,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please name your vehicle';
                  }
                  return null;
                },
                onSaved: (val) {
                  _name = val!.trim();
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MileageUnit>(
                key: VehicleFormScreen.mileageUnitFieldKey,
                decoration: InputDecoration(
                  labelText: 'Mileage Unit',
                  helperText: _isEditing ? 'Existing mileage values will not be converted.' : null,
                ),
                initialValue: widget.vehicle?.mileageUnit ?? .mi,
                items: MileageUnit.values
                    .map((it) => DropdownMenuItem<MileageUnit>(value: it, child: Text(it.name)))
                    .toList(),
                onSaved: (val) {
                  _mileageUnit = val!;
                },
                onChanged: _submission.isSubmitting ? null : (_) {}, // enables the control
              ),
              DateFormField(
                key: VehicleFormScreen.dateFieldKey,
                enabled: !_submission.isSubmitting,
                initialValue: widget.vehicle?.manufactureDate,
                decoration: InputDecoration(labelText: 'Manufacture Date'),
                validator: (val) {
                  if (val == null) {
                    return 'The date is needed to calculate services due';
                  }
                  return null;
                },
                now: widget.now,
                onSaved: (val) {
                  _manufactureDate = val;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: VehicleFormScreen.saveButtonKey,
                onPressed: _submission.isSubmitting ? null : _saveForm,
                child: _submission.isSubmitting ? Text('Saving...') : Text('Save'),
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
        await _persistVehicle();
      } on CreateConflict {
        hasConflict = true;
        rethrow;
      }
    });
    if (hasConflict) onCreateConflict?.call();
    if (!mounted) return;
    switch (result) {
      case SubmissionSuccess():
        Navigator.of(context).pop(true);
      case SubmissionFailure():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: VehicleFormScreen.errorSnackBarKey,
              content: Text(
                hasConflict
                    ? 'This vehicle ID already exists. Go back to check the garage.'
                    : 'Save failed. Please try again.',
              ),
            ),
          );
      case SubmissionIgnored():
        return;
    }
  }

  Future<void> _persistVehicle() async {
    final vehicle = widget.vehicle;
    if (vehicle != null) {
      await _repo.update(
        vehicle.id,
        name: _name,
        manufactureDate: _manufactureDate!,
        mileageUnit: _mileageUnit,
      );
    } else {
      await _repo.create(
        id: _draftId,
        name: _name,
        manufactureDate: _manufactureDate!,
        mileageUnit: _mileageUnit,
      );
    }
  }
}
