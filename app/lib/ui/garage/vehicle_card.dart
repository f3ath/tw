import 'package:app/ui/garage/vehicle_due_schedules.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:shared/time.dart';

class const VehicleCard({
  super.key,
  required final Vehicle vehicle,
  required final CalendarDate asOf,
  required final ValueChanged<VehicleAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String vehicleId) => ValueKey('menu-$vehicleId');
  static ValueKey<String> newServiceButtonKey(String vehicleId) =>
      ValueKey('vehicle-new-service-$vehicleId');

  @override
  Widget build(BuildContext context) {
    final age = Age.between(vehicle.manufactureDate, asOf);
    return Card(
      child: Column(
        mainAxisSize: .min,
        children: [
          ListTile(
            titleAlignment: ListTileTitleAlignment.top,
            title: Text(vehicle.name),
            subtitle: Text('${age.years > 0 ? '${age.years} yr ' : ''}${age.months} mon old'),
            trailing: _VehicleMenu(
              vehicleId: vehicle.id,
              vehicleName: vehicle.name,
              onAction: onAction,
            ),
          ),
          VehicleDueSchedules(key: ValueKey(vehicle.id), vehicle: vehicle, asOf: asOf),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: VehicleCard.newServiceButtonKey(vehicle.id),
                onPressed: () => onAction(VehicleAction.newService),
                icon: const Icon(Icons.add),
                label: const Text('Log Service'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _VehicleMenu({
  required final String vehicleId,
  required final String vehicleName,
  required final ValueChanged<VehicleAction> onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PopupMenuButton<VehicleAction>(
    key: VehicleCard.menuKey(vehicleId),
    tooltip: 'Manage $vehicleName',
    icon: const Icon(Icons.more_vert),
    itemBuilder: (_) => const [
      PopupMenuItem(
        key: ValueKey('edit'),
        value: VehicleAction.edit,
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Edit')),
          ],
        ),
      ),
      PopupMenuItem(
        key: ValueKey('schedules'),
        value: VehicleAction.schedules,
        child: Row(
          children: [
            Icon(Icons.event_repeat, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Schedules')),
          ],
        ),
      ),
      PopupMenuItem(
        key: ValueKey('services'),
        value: VehicleAction.services,
        child: Row(
          children: [
            Icon(Icons.build_outlined, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Services')),
          ],
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        key: ValueKey('delete'),
        value: VehicleAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Delete')),
          ],
        ),
      ),
    ],
    onSelected: onAction,
  );
}

enum VehicleAction { edit, schedules, services, newService, delete }
