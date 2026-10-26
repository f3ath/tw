import 'package:flutter/material.dart';

import 'form_view_models.dart';

Widget field(
  String label,
  String value,
  ValueChanged<String> update, {
  String? error,
  String? hint,
  bool number = false,
  bool enabled = true,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 10),
  child: TextFormField(
    initialValue: value,
    enabled: enabled,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      helperText: hint,
      helperMaxLines: 4,
      border: const OutlineInputBorder(),
    ),
    onChanged: update,
  ),
);

class const DraftView({
  super.key,
  required final DraftViewModel model,
  required final List<Widget> children,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AbsorbPointer(
            absorbing: model.busy,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
          if (model.failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                model.failure!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (model.busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: model.busy ? null : onSave,
            child: Text(model.failure == null ? 'Save' : 'Retry save'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class const VehicleFormView({
  super.key,
  required final VehicleFormViewModel model,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => DraftView(
      model: model,
      onSave: onSave,
      children: [
        field('Display name', model.name, (v) {
          model.name = v;
          model.changed();
        }, error: model.error('name')),
        DateField(
          value: model.date,
          label: 'Manufacture date',
          error: model.error('date'),
          onChanged: (v) {
            model.date = v;
            model.changed();
          },
        ),
        if (model.original == null) ...[
          DropdownButtonFormField<String>(
            initialValue: model.unit,
            decoration: const InputDecoration(labelText: 'Distance unit'),
            items: const [
              DropdownMenuItem(value: 'mi', child: Text('Miles')),
              DropdownMenuItem(value: 'km', child: Text('Kilometers')),
            ],
            onChanged: (v) {
              model.unit = v!;
              model.changed();
            },
          ),
          field(
            'Current odometer',
            model.mileage,
            (v) {
              model.mileage = v;
              model.changed();
            },
            number: true,
            error: model.error('mileage'),
            hint: 'This creates a mileage-only service dated today.',
          ),
        ] else
          Text(
            'Distance unit: ${model.unit} · fixed after creation. Use Update mileage for a new reading.',
          ),
      ],
    ),
  );
}

class const ItemFormView({
  super.key,
  required final ItemFormViewModel model,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => DraftView(
      model: model,
      onSave: onSave,
      children: [
        field('Description', model.description, (v) {
          model.description = v;
          model.changed();
        }, error: model.error('description')),
        field(
          'Every · ${model.vehicle.unit}',
          model.distance,
          (v) {
            model.distance = v;
            model.changed();
          },
          number: true,
          error: model.error('interval'),
        ),
        field('Every · months', model.months, (v) {
          model.months = v;
          model.changed();
        }, number: true),
        const Text(
          'Enter at least one positive interval. When both are set, maintenance is due when either limit is reached. One month = 30 days.',
        ),
        if (model.original != null)
          const Text(
            'Changing intervals recalculates when this item is due. Linked history uses the current description.',
          ),
      ],
    ),
  );
}

class const ServiceFormView({
  super.key,
  required final ServiceFormViewModel model,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => DraftView(
      model: model,
      onSave: onSave,
      children: [
        Text(model.vehicle.name, style: Theme.of(context).textTheme.titleLarge),
        DateField(
          value: model.date,
          label: 'Date',
          error: model.error('date'),
          onChanged: (v) {
            model.date = v;
            model.changed();
          },
        ),
        field(
          'Odometer',
          model.mileage,
          (v) {
            model.mileage = v;
            model.changed();
          },
          number: true,
          error: model.error('mileage'),
          hint:
              'Estimated now: ${model.estimate ?? 'Unknown'} ${model.vehicle.unit}. Enter the actual reading.',
        ),
        if (model.isToday && model.suggestions.isNotEmpty) ...[
          const Text('Overdue suggestions'),
          const Text('Select only the work you performed.'),
          for (final item in model.suggestions)
            CheckboxListTile(
              title: Text(item.description),
              value: model.selected.contains(item.id),
              onChanged: (v) => model.toggle(item.id, v!),
            ),
        ],
        Text(model.isToday ? 'Other scheduled maintenance' : 'Scheduled maintenance'),
        for (final item in model.others)
          CheckboxListTile(
            title: Text('${item.description}${item.archived ? ' · Archived' : ''}'),
            value: model.selected.contains(item.id),
            onChanged: (v) => model.toggle(item.id, v!),
          ),
        const SizedBox(height: 16),
        const Text('Custom operations'),
        for (var i = 0; i < model.custom.length; i++)
          Row(
            key: ValueKey('custom-$i-${model.custom.length}'),
            children: [
              Expanded(
                child: field('Custom operation', model.custom[i], (v) {
                  model.custom[i] = v;
                  model.changed();
                }),
              ),
              IconButton(
                tooltip: 'Remove custom operation',
                onPressed: () {
                  model.custom.removeAt(i);
                  model.changed();
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: () {
            model.custom.add('');
            model.changed();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add custom operation'),
        ),
        Text(
          model.count == 0
              ? 'Saved as a mileage-only entry. No maintenance operations recorded.'
              : '${model.count} operations selected',
        ),
      ],
    ),
  );
}

class const SettingsView({
  super.key,
  required final SettingsViewModel model,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (model.busy && model.address.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return DraftView(
        model: model,
        onSave: onSave,
        children: [
          field('Server address', model.address, (v) {
            model.address = v;
            model.changed();
          }, error: model.error('address')),
        ],
      );
    },
  );
}

class const DateField({
  super.key,
  required final String value,
  required final String label,
  required final ValueChanged<String> onChanged,
  final String? error,
}) extends StatefulWidget {
  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState() extends State<DateField> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'YYYY-MM-DD',
        errorText: widget.error,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Choose ${widget.label}',
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(widget.value) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (date != null) {
              final text =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              controller.text = text;
              widget.onChanged(text);
            }
          },
        ),
      ),
      onChanged: widget.onChanged,
    ),
  );
}
