import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/form/date_form_field.dart';

class const VehicleFormScreen({
  super.key,
  required final VehicleRepo repo,
  final Clock clock = const Clock(),
  final Vehicle? vehicle,
}) extends StatefulWidget {
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
  static const nameFieldKey = ValueKey('vehicle-name-field');
  static const distanceUnitFieldKey = ValueKey('vehicle-distance-unit-field');
  static const dateFieldKey = ValueKey('vehicle-date-field');
  static const saveButtonKey = ValueKey('vehicle-save-button');
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DistanceUnit _distanceUnit = .mi;
  DateTime? _manufactureDate;
  String _name = '';
  var _isSaving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_isEditing ? 'Edit Vehicle' : 'Add Vehicle')),
    body: Padding(
      padding: .all(10),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Name'),
              key: VehicleFormScreen.nameFieldKey,
              initialValue: widget.vehicle?.name,
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
              onChanged: _isEditing ? null : (_) {}, // enables the control
            ),
            DateFormField(
              key: VehicleFormScreen.dateFieldKey,
              format: _formatDate,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
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

            FilledButton(
              key: VehicleFormScreen.saveButtonKey,
              onPressed: _isSaving ? null : _saveForm,
              child: _isSaving ? Text('Saving...') : Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _saveForm() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      _isSaving = true;
    });
    try {
      await _persistVehicle();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Save failed. Please try again.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _persistVehicle() async {
    final vehicle = widget.vehicle;
    if (vehicle != null) {
      await widget.repo.updateVehicle(vehicle.id, name: _name, manufactureDate: _manufactureDate!);
    } else {
      await widget.repo.createVehicle(
        name: _name,
        manufactureDate: _manufactureDate!,
        distanceUnit: _distanceUnit,
      );
    }
  }
}

String _formatDate(DateTime? value) => value == null
    ? ''
    : DateTime(value.year, value.month, value.day).toIso8601String().split('T').first;
