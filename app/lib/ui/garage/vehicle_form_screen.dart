import 'package:material_ui/material_ui.dart';
import 'package:app/ui/form/form_submission_controller.dart';
import 'package:app/app/repository_provider.dart';
import 'package:shared/model.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/time/clock.dart';
import 'package:app/ui/form/date_form_field.dart';

class const VehicleFormScreen({
  super.key,
  final Clock clock = const Clock(),
  final Vehicle? vehicle,
}) extends StatefulWidget {
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
  static const errorSnackBarKey = ValueKey('vehicle-save-error-snackbar');
  static const nameFieldKey = ValueKey('vehicle-name-field');
  static const distanceUnitFieldKey = ValueKey('vehicle-distance-unit-field');
  static const dateFieldKey = ValueKey('vehicle-date-field');
  static const saveButtonKey = ValueKey('vehicle-save-button');
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  late final VehicleRepo _repo = RepositoryProvider.read(context).vehicleRepo;
  final _formKey = GlobalKey<FormState>();
  DistanceUnit _distanceUnit = .mi;
  DateTime? _manufactureDate;
  String _name = '';
  final _submission = FormSubmissionController();

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
              DropdownButtonFormField<DistanceUnit>(
                key: VehicleFormScreen.distanceUnitFieldKey,
                decoration: InputDecoration(labelText: 'Distance Unit'),
                initialValue: widget.vehicle?.distanceUnit ?? .mi,
                items: DistanceUnit.values
                    .map((it) => DropdownMenuItem<DistanceUnit>(value: it, child: Text(it.name)))
                    .toList(),
                onSaved: (val) {
                  _distanceUnit = val!;
                },
                onChanged: _isEditing || _submission.isSubmitting
                    ? null
                    : (_) {}, // enables the control
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
                clock: widget.clock,
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
    final saved = await _submission.submit(_persistVehicle);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (_submission.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: VehicleFormScreen.errorSnackBarKey,
            content: Text('Save failed. Please try again.'),
          ),
        );
    }
  }

  Future<void> _persistVehicle() async {
    final vehicle = widget.vehicle;
    if (vehicle != null) {
      await _repo.update(vehicle.id, name: _name, manufactureDate: _manufactureDate!);
    } else {
      await _repo.create(
        name: _name,
        manufactureDate: _manufactureDate!,
        distanceUnit: _distanceUnit,
      );
    }
  }
}
