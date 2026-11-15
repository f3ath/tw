import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const VehicleCard({
  super.key,
  required final Vehicle vehicle,
  required final DateTime now,
  required final ValueChanged<VehicleAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String vehicleId) => ValueKey('menu-$vehicleId');
  static ValueKey<String> newServiceButtonKey(String vehicleId) =>
      ValueKey('vehicle-new-service-$vehicleId');

  @override
  Widget build(BuildContext context) {
    final age = vehicle.ageAsOf(now);
    return Card(
      child: Column(
        mainAxisSize: .min,
        children: [
          ListTile(
            title: Text(vehicle.name),
            subtitle: Text('${age.years > 0 ? '${age.years} yr ' : ''}${age.months} mon old'),
            trailing: PopupMenuButton<VehicleAction>(
              key: VehicleCard.menuKey(vehicle.id),
              tooltip: 'Manage ${vehicle.name}',
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
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Text('Services due will go here')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: VehicleCard.newServiceButtonKey(vehicle.id),
                onPressed: () => onAction(VehicleAction.newService),
                icon: const Icon(Icons.add),
                label: const Text('New Service'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum VehicleAction { edit, schedules, services, newService, delete }
