import 'package:flutter/material.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:shared/model.dart';
import 'package:tw_app/time/clock.dart';

class const VehicleFormScreen({
  super.key,
  required final VehicleRepo repo,
  final Clock clock = const Clock(),
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
  late final dateController = TextEditingController();
  DistanceUnit distanceUnit = .mi;
  DateTime? manufactureDate;
  final formKey = GlobalKey<FormState>();
  var _isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();
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
            TextFormField(
              key: VehicleFormScreen.dateFieldKey,
              controller: dateController,
              readOnly: true,
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: manufactureDate ?? widget.clock.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (!mounted || selected == null) return;
                setState(() {
                  manufactureDate = selected;
                  dateController.text = day(selected);
                });
              },
              decoration: InputDecoration(labelText: 'Manufacture Date'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'The date is needed to calculate services due';
                }
                return null;
              },
            ),
            FilledButton(
              key: VehicleFormScreen.saveButtonKey,
              onPressed: _isSaving
                  ? null
                  : () async {
                      final valid = formKey.currentState!.validate();
                      if (!valid) return;
                      setState(() {
                        _isSaving = true;
                      });
                      try {
                        await widget.repo.createVehicle(
                          name: nameController.text.trim(),
                          manufactureDate: manufactureDate!,
                          distanceUnit: distanceUnit,
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSaving = false;
                          });
                        }
                      }
                    },
              child: _isSaving ? Text('Saving...') : Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
}

String day(DateTime? value) => value == null
    ? ''
    : DateTime(value.year, value.month, value.day).toIso8601String().split('T').first;
