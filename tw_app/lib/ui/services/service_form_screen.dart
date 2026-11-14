import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/form/date_form_field.dart';

class const ServiceFormScreen({
  super.key,
  required final Vehicle vehicle,
  final Clock clock = const Clock(),
}) extends StatefulWidget {
  static const dateFieldKey = ValueKey('service-date-field');
  static const odometerFieldKey = ValueKey('service-odometer-field');
  static const detailsFieldKey = ValueKey('service-details-field');
  static const saveButtonKey = ValueKey('service-save-button');

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _detailsController = TextEditingController();

  DateTime get _latestDate {
    final now = widget.clock.now();
    return DateTime(now.year, now.month, now.day + 7);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Service')),
    body: SafeArea(
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Text(widget.vehicle.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DateFormField(
              key: ServiceFormScreen.dateFieldKey,
              initialValue: widget.clock.now(),
              firstDate: DateTime(1900),
              lastDate: _latestDate,
              validator: (value) {
                if (value == null) return 'Please select a date';
                final date = DateTime(value.year, value.month, value.day);
                return date.isAfter(_latestDate) ? 'Choose a date no more than 7 days ahead' : null;
              },
              decoration: const InputDecoration(labelText: 'Date'),
              clock: widget.clock,
            ),
            TextFormField(
              key: ServiceFormScreen.odometerFieldKey,
              validator: (value) {
                final odometer = int.tryParse(value?.trim() ?? '');
                return odometer == null || odometer < 0 ? 'Enter a nonnegative whole number' : null;
              },
              decoration: InputDecoration(
                labelText: 'Odometer',
                suffixText: widget.vehicle.distanceUnit.name,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              key: ServiceFormScreen.detailsFieldKey,
              controller: _detailsController,
              onSaved: (value) => _detailsController.text = value?.trim() ?? '',
              decoration: const InputDecoration(labelText: 'Details (optional)'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const FilledButton(
              key: ServiceFormScreen.saveButtonKey,
              onPressed: null,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
}
