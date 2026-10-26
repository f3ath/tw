import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/policies.dart';
import 'garage_view_model.dart';

String recurrence(MaintenanceItem i, String unit) =>
    'Every ${[if (i.distance != null) '${i.distance} $unit', if (i.months != null) '${i.months} months'].join(' or ')}${i.distance != null && i.months != null ? ', whichever comes first' : ''}';

class const Reading({
  super.key,
  required final GarageViewModel model,
  required final Vehicle vehicle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final last = model.data.history(vehicle.id).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated: ${model.data.estimate(vehicle.id) ?? 'Unknown'} ${vehicle.unit}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          last == null
              ? 'No recorded mileage. Distance status unavailable.'
              : 'Latest recorded: ${last.mileage} ${vehicle.unit} · ${dateText(last.date)}',
        ),
      ],
    );
  }
}

class const GarageView({
  super.key,
  required final GarageViewModel model,
  required final ValueChanged<String> openVehicle,
  required final VoidCallback addVehicle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          key: const PageStorageKey('garage'),
          padding: const EdgeInsets.all(16),
          children: [
            if (model.data.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No vehicles yet. Add your first vehicle to track maintenance.'),
              ),
            for (final vehicle in model.data.vehicles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.directions_car_outlined),
                        title: Text(vehicle.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => openVehicle(vehicle.id),
                      ),
                      Reading(model: model, vehicle: vehicle),
                      const Divider(height: 28),
                      for (final due in model.due(vehicle.id).take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${due.item.description} · ${due.label}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(due.reason(vehicle.unit)),
                            ],
                          ),
                        ),
                      if (model.due(vehicle.id).isEmpty)
                        Text(
                          model.incomplete(vehicle.id)
                              ? 'Distance status unavailable'
                              : 'No maintenance due soon',
                        ),
                      if (model.due(vehicle.id).length > 3)
                        TextButton(
                          onPressed: () => openVehicle(vehicle.id),
                          child: Text('${model.due(vehicle.id).length - 3} more...'),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: model.offline ? null : addVehicle,
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}

class const VehicleView({
  super.key,
  required final GarageViewModel model,
  required final String vehicleId,
  required final ValueChanged<String> openItem,
  required final ValueChanged<String> openService,
  required final VoidCallback addItem,
  required final VoidCallback logService,
  required final VoidCallback editVehicle,
  required final ValueChanged<int> onTabChanged,
  final int initialTab = 0,
}) extends StatefulWidget {
  @override
  State<VehicleView> createState() => _VehicleViewState();
}

class _VehicleViewState() extends State<VehicleView> with SingleTickerProviderStateMixin {
  late final TabController controller;
  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  late int tab = widget.initialTab;
  bool archived = false;
  int historyLimit = 30;
  void selectTab(int value) {
    setState(() {
      tab = value;
      controller.index = value;
    });
    widget.onTabChanged(value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final vm = widget.model;
      final vehicle = vm.data.vehicle(widget.vehicleId);
      final due = vm.due(vehicle.id);
      final history = vm.data.history(vehicle.id);
      final content = ListView(
        key: PageStorageKey('${vehicle.id}-$tab-$archived'),
        padding: const EdgeInsets.all(20),
        children: [
          Reading(model: vm, vehicle: vehicle),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: vm.offline ? null : widget.logService,
                child: const Text('Update mileage'),
              ),
              TextButton(
                onPressed: vm.offline ? null : widget.editVehicle,
                child: const Text('Edit vehicle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: vm.offline
                  ? null
                  : tab == 1
                  ? widget.addItem
                  : widget.logService,
              icon: Icon(tab == 1 ? Icons.add : Icons.build_outlined),
              label: Text(tab == 1 ? 'Add item' : 'Log service'),
            ),
          ),
          const SizedBox(height: 20),
          if (tab == 0) ...[
            if (due.isEmpty) ...[
              Text(
                vm.data.items.any((i) => i.vehicleId == vehicle.id && !i.archived)
                    ? (vm.incomplete(vehicle.id)
                          ? 'Distance status unavailable'
                          : 'No maintenance due soon')
                    : 'No schedule yet',
              ),
              TextButton(onPressed: () => selectTab(1), child: const Text('Go to Schedule')),
            ],
            for (final status in [DueStatus.overdue, DueStatus.soon]) ...[
              if (due.any((d) => d.status == status))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    status == DueStatus.overdue ? 'Overdue' : 'Due soon',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              for (final d in due.where((d) => d.status == status))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.item.description),
                  subtitle: Text('${d.label} · ${d.reason(vehicle.unit)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.openItem(d.item.id),
                ),
            ],
          ],
          if (tab == 1) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Active')),
                ButtonSegment(value: true, label: Text('Archived')),
              ],
              selected: {archived},
              onSelectionChanged: (s) => setState(() => archived = s.first),
            ),
            const SizedBox(height: 16),
            if (vm.schedule(vehicle.id, archived).isEmpty)
              Text(
                archived ? 'No archived items' : 'No maintenance items yet. Add maintenance item.',
              ),
            for (final item in vm.schedule(vehicle.id, archived))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.description),
                subtitle: Text(
                  '${recurrence(item, vehicle.unit)}\n${item.archived ? 'Archived' : vm.status(item).label}',
                ),
                isThreeLine: true,
                onTap: () => widget.openItem(item.id),
                trailing: const Icon(Icons.chevron_right),
              ),
          ],
          if (tab == 2) ...[
            if (history.isEmpty) const Text('No service records.'),
            for (final s in history.take(historyLimit))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${dateText(s.date)} · ${s.mileage} ${vehicle.unit}'),
                subtitle: Text(vm.summary(s).isEmpty ? 'Mileage update' : vm.summary(s)),
                onTap: () => widget.openService(s.id),
                trailing: const Icon(Icons.chevron_right),
              ),
            if (history.length > historyLimit)
              TextButton(
                onPressed: () => setState(() => historyLimit += 30),
                child: const Text('Load more history'),
              ),
          ],
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: selectTab,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.upcoming_outlined),
                      label: Text('Due'),
                    ),
                    NavigationRailDestination(icon: Icon(Icons.checklist), label: Text('Schedule')),
                    NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          }
          return Column(
            children: [
              TabBar(
                controller: controller,
                onTap: selectTab,
                tabs: const [
                  Tab(text: 'Due'),
                  Tab(text: 'Schedule'),
                  Tab(text: 'History'),
                ],
              ),
              Expanded(child: content),
            ],
          );
        },
      );
    },
  );
}

class const ItemDetailView({
  super.key,
  required final GarageViewModel model,
  required final String id,
  required final VoidCallback edit,
  required final VoidCallback archive,
  required final ValueChanged<String> openService,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final item = model.data.item(id);
      final vehicle = model.data.vehicle(item.vehicleId);
      final status = model.status(item);
      return detailList([
        Text(item.description, style: Theme.of(context).textTheme.headlineSmall),
        Text(recurrence(item, vehicle.unit)),
        const SizedBox(height: 16),
        if (item.archived)
          const Text('Archived')
        else ...[
          Text('${status.label} · ${status.reason(vehicle.unit)}'),
          const SizedBox(height: 16),
          const Text('Next due'),
          Text(
            [
              if (status.dateDue != null) dateText(status.dateDue!),
              if (status.distanceDue != null) '${status.distanceDue} ${vehicle.unit}',
            ].join(' · '),
          ),
          const SizedBox(height: 16),
          const Text('Last completed'),
          Text(
            status.last == null
                ? 'No recorded service — calculated from manufacture date and 0 ${vehicle.unit}.'
                : '${dateText(status.last!.date)} · ${status.last!.mileage} ${vehicle.unit}',
          ),
        ],
        const SizedBox(height: 24),
        const Text('Service history'),
        for (final s in model.data.history(vehicle.id).where((s) => s.links.contains(id)))
          ListTile(
            title: Text('${dateText(s.date)} · ${s.mileage} ${vehicle.unit}'),
            onTap: () => openService(s.id),
          ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: model.offline || model.busy ? null : edit,
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: model.offline || model.busy ? null : archive,
              child: Text(item.archived ? 'Restore item' : 'Archive item'),
            ),
          ],
        ),
        if (model.failure != null) Text(model.failure!.message),
        if (model.busy) const LinearProgressIndicator(),
      ]);
    },
  );
}

class const ServiceDetailView({
  super.key,
  required final GarageViewModel model,
  required final String id,
  required final VoidCallback edit,
  required final VoidCallback delete,
  required final ValueChanged<String> openItem,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (!model.data.services.any((s) => s.id == id)) {
        return const Center(child: Text('Service unavailable.'));
      }
      final s = model.data.service(id);
      final vehicle = model.data.vehicle(s.vehicleId);
      return detailList([
        Text(
          '${dateText(s.date)} · ${s.mileage} ${vehicle.unit}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        if (s.links.isEmpty && s.custom.isEmpty) const Text('No maintenance operations recorded.'),
        for (final id in s.links)
          ListTile(
            title: Text(model.data.item(id).description),
            subtitle: model.data.item(id).archived ? const Text('Archived') : null,
            onTap: () => openItem(id),
          ),
        for (final text in s.custom) ListTile(title: Text(text), subtitle: const Text('Custom')),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: model.busy || model.offline ? null : edit,
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: model.busy || model.offline ? null : delete,
              child: const Text('Delete service'),
            ),
          ],
        ),
        if (model.failure != null) Text(model.failure!.message),
        if (model.busy) const LinearProgressIndicator(),
      ]);
    },
  );
}

Widget detailList(List<Widget> children) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: ListView(padding: const EdgeInsets.all(24), children: children),
  ),
);
