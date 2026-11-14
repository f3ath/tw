import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ScheduleFormScreen({
  super.key,
  required final Vehicle vehicle,
  final Schedule? schedule,
}) extends StatelessWidget {
  static const nameFieldKey = ValueKey('schedule-name-field');
  static const distanceFieldKey = ValueKey('schedule-distance-field');
  static const monthsFieldKey = ValueKey('schedule-months-field');
  static const detailsFieldKey = ValueKey('schedule-details-field');
  static const saveButtonKey = ValueKey('schedule-save-button');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(schedule == null ? 'Add Schedule' : 'Edit Schedule')),
    body: SafeArea(
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Text(vehicle.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              key: nameFieldKey,
              initialValue: schedule?.name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const Text('Repeat by distance, time, or both.'),
            TextFormField(
              key: distanceFieldKey,
              initialValue: schedule?.intervalDistance?.toString(),
              decoration: InputDecoration(
                labelText: 'Distance interval',
                suffixText: vehicle.distanceUnit.name,
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              key: monthsFieldKey,
              initialValue: schedule?.intervalMonths?.toString(),
              decoration: const InputDecoration(labelText: 'Time interval', suffixText: 'months'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              key: detailsFieldKey,
              initialValue: schedule?.details,
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
