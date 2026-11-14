import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/form/date_form_field.dart';

class const ServiceFormScreen({
  super.key,
  required final Vehicle vehicle,
  final Clock clock = const Clock(),
}) extends StatelessWidget {
  static const dateFieldKey = ValueKey('service-date-field');
  static const odometerFieldKey = ValueKey('service-odometer-field');
  static const detailsFieldKey = ValueKey('service-details-field');
  static const saveButtonKey = ValueKey('service-save-button');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Service')),
    body: SafeArea(
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Text(vehicle.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DateFormField(
              key: dateFieldKey,
              initialValue: clock.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              decoration: const InputDecoration(labelText: 'Date'),
              clock: clock,
            ),
            TextFormField(
              key: odometerFieldKey,
              decoration: InputDecoration(
                labelText: 'Odometer',
                suffixText: vehicle.distanceUnit.name,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              key: detailsFieldKey,
              decoration: const InputDecoration(labelText: 'Details (optional)'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const FilledButton(key: saveButtonKey, onPressed: null, child: Text('Save')),
          ],
        ),
      ),
    ),
  );
}
