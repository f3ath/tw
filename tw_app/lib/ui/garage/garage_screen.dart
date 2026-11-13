import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_view_model.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  required final VehicleRepo repo,
  final Clock clock = const Clock(),
}) extends StatefulWidget {
  static const userNameTextKey = ValueKey('user-name-text');
  static const logoutButtonKey = ValueKey('logout-button');
  static const retryButtonKey = ValueKey('retry-button');
  static const addButtonKey = ValueKey('add-button');

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  late final GarageViewModel model;

  @override
  void initState() {
    super.initState();
    model = GarageViewModel(vehicleRepository: widget.repo);
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Icon(Icons.garage_outlined, size: 30),
          SizedBox(width: 10),
          Text('Garage'),
        ],
      ),
      actions: [
        Text(
          widget.userName,
          key: GarageScreen.userNameTextKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        IconButton(
          key: GarageScreen.logoutButtonKey,
          onPressed: widget.onLogout,
          icon: Icon(Icons.logout),
          tooltip: 'Logout',
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: model,
      builder: (_, _) {
        if (model.isLoading) {
          return Center(child: CircularProgressIndicator());
        }
        if (model.hasError) {
          return Center(
            child: Column(
              children: [
                Text('Error loading vehicles :('),
                FilledButton(
                  key: GarageScreen.retryButtonKey,
                  onPressed: model.load,
                  child: Text('Retry.'),
                ),
              ],
            ),
          );
        }
        if (model.vehicles.isEmpty) {
          return Center(child: Text('Nothing yet'));
        }
        return ListView.builder(
          itemCount: model.vehicles.length,
          itemBuilder: (BuildContext context, int index) {
            final v = model.vehicles[index];
            final age = v.ageAsOf(widget.clock.now());
            return Card(
              key: ValueKey('vehicle-${v.id}'),
              child: Column(
                mainAxisSize: .min,
                children: [
                  ListTile(
                    title: Text(v.name),
                    subtitle: Text(
                      '${age.years > 0 ? '${age.years} yr ' : ''}${age.months} mon old',
                    ),
                    trailing: PopupMenuButton<VehicleAction>(
                      key: ValueKey('menu-${v.id}'),
                      tooltip: 'Manage ${v.name}',
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          key: ValueKey('edit'),
                          value: VehicleAction.edit,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('Edit vehicle')),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          key: ValueKey('schedules'),
                          value: VehicleAction.schedules,
                          child: Row(
                            children: [
                              Icon(Icons.event_repeat, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('Manage schedules')),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          key: ValueKey('delete'),
                          value: VehicleAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('Delete vehicle')),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (action) async {
                        debugPrint('${v.id}: $action');
                        if (action == .edit) {
                          final updated = await Navigator.of(context).push<Vehicle>(
                            MaterialPageRoute(
                              builder: (_) => VehicleFormScreen(
                                repo: widget.repo,
                                clock: widget.clock,
                                vehicle: v,
                              ),
                            ),
                          );
                          if (updated != null && mounted) {
                            await model.load();
                          }
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Services due will go here'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      key: GarageScreen.addButtonKey,
      tooltip: 'Add new vehicle',
      child: const Icon(Icons.add),
      onPressed: () async {
        final newVehicle = await Navigator.of(context).push<Vehicle>(
          MaterialPageRoute(
            builder: (_) => VehicleFormScreen(repo: widget.repo, clock: widget.clock),
          ),
        );
        if (newVehicle != null && mounted) {
          await model.load();
        }
      },
    ),
  );
}

enum VehicleAction { edit, schedules, delete }
