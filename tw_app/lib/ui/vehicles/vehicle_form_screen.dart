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
  late final nameController = TextEditingController();
  DistanceUnit distanceUnit = .mi;
  DateTime? _manufactureDate;
  final formKey = GlobalKey<FormState>();
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _manufactureDate = widget.vehicle?.manufactureDate;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Add Vehicle')),
    body: Padding(
      padding: .all(10),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Name'),
              key: VehicleFormScreen.nameFieldKey,
              controller: nameController,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please name your vehicle';
                }
                return null;
              },
            ),
            DropdownButtonFormField<DistanceUnit>(
              key: VehicleFormScreen.distanceUnitFieldKey,
              decoration: InputDecoration(labelText: 'Distance Unit'),
              initialValue: distanceUnit,
              items: DistanceUnit.values
                  .map((it) => DropdownMenuItem<DistanceUnit>(value: it, child: Text(it.name)))
                  .toList(),
              onChanged: (it) => setState(() {
                distanceUnit = it ?? .mi;
              }),
            ),
            // TextFormField(
            //   key: VehicleFormScreen.dateFieldKey,
            //   controller: dateController,
            //   readOnly: true,
            //   onTap: () async {
            //     final selected = await showDatePicker(
            //       context: context,
            //       initialDate: _manufactureDate ?? widget.clock.now(),
            //       firstDate: DateTime(1900),
            //       lastDate: DateTime(2100),
            //     );
            //     if (!mounted || selected == null) return;
            //     setState(() {
            //       _setManufactureDate(selected);
            //     });
            //   },
            //   decoration: InputDecoration(labelText: 'Manufacture Date'),
            //   validator: (val) {
            //     if (val == null || val.trim().isEmpty) {
            //       return 'The date is needed to calculate services due';
            //     }
            //     return null;
            //   },
            // ),
            DateFormField(
              key: VehicleFormScreen.dateFieldKey,
              format: day,
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
    final form = formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      _isSaving = true;
    });
    try {
      final vehicle = await widget.repo.createVehicle(
        name: nameController.text.trim(),
        manufactureDate: _manufactureDate!,
        distanceUnit: distanceUnit,
      );
      if (!mounted) return;
      Navigator.of(context).pop(vehicle);
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
}

String day(DateTime? value) => value == null
    ? ''
    : DateTime(value.year, value.month, value.day).toIso8601String().split('T').first;
