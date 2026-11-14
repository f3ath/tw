import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/service_repo.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/form/date_form_field.dart';

class const ServiceFormScreen({
  super.key,
  required final Vehicle vehicle,
  required final ServiceRepo repo,
  final Clock clock = const Clock(),
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
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late int _odometer;
  var _details = '';
  var _isSaving = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Service')),
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
              initialValue: widget.clock.now(),
              enabled: !_isSaving,
              validator: (value) => value == null ? 'Please select a date' : null,
              onSaved: (value) => _date = value!,
              decoration: const InputDecoration(labelText: 'Date'),
              clock: widget.clock,
            ),
            TextFormField(
              key: ServiceFormScreen.odometerFieldKey,
              enabled: !_isSaving,
              validator: (value) {
                final odometer = int.tryParse(value?.trim() ?? '');
                return odometer == null || odometer < 0 ? 'Enter a nonnegative whole number' : null;
              },
              onSaved: (value) => _odometer = int.parse(value!.trim()),
              decoration: InputDecoration(
                labelText: 'Odometer',
                suffixText: widget.vehicle.distanceUnit.name,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              key: ServiceFormScreen.detailsFieldKey,
              enabled: !_isSaving,
              onSaved: (value) => _details = value?.trim() ?? '',
              decoration: const InputDecoration(labelText: 'Details (optional)'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: ServiceFormScreen.saveButtonKey,
              onPressed: _isSaving ? null : _saveForm,
              child: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _saveForm() async {
    if (_isSaving) return;
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() => _isSaving = true);
    try {
      await widget.repo.create(
        widget.vehicle.id,
        date: _date,
        odometer: _odometer,
        details: _details,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: ServiceFormScreen.errorSnackBarKey,
              content: Text('Save failed. Please try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
