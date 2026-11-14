import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_view_model.dart';
import 'package:tw_app/ui/garage/vehicle_card.dart';
import 'package:tw_app/ui/vehicles/vehicle_form_screen.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  required final VehicleRepo repo,
  final Clock clock = const Clock(),
}) extends StatefulWidget {
  static ValueKey<String> vehicleCardKey(String vehicleId) => ValueKey('vehicle-$vehicleId');

  static const userNameTextKey = ValueKey('user-name-text');
  static const logoutButtonKey = ValueKey('logout-button');
  static const retryButtonKey = ValueKey('retry-button');
  static const addButtonKey = ValueKey('add-button');
  static const deleteConfirmation = ValueKey('delete-confirmation');
  static const deleteButton = ValueKey('delete-confirmation-delete');
  static const cancelButton = ValueKey('delete-confirmation-cancel');

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  late final GarageViewModel _model;

  @override
  void initState() {
    super.initState();
    _model = GarageViewModel(vehicleRepository: widget.repo);
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [Icon(Icons.garage_outlined, size: 30), SizedBox(width: 10), Text('Garage')],
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
      listenable: _model,
      builder: (_, _) {
        if (_model.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              children: [
                Text('Error loading vehicles :('),
                FilledButton(
                  key: GarageScreen.retryButtonKey,
                  onPressed: _model.load,
                  child: Text('Retry.'),
                ),
              ],
            ),
          );
        }
        if (_model.vehicles.isEmpty) {
          return Center(child: Text('Nothing yet'));
        }
        return ListView.builder(
          itemCount: _model.vehicles.length,
          itemBuilder: (_, index) => _buildVehicleCard(_model.vehicles[index]),
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      key: GarageScreen.addButtonKey,
      tooltip: 'Add new vehicle',
      child: const Icon(Icons.add),
      onPressed: () async {
        final refresh = await _openVehicleForm();
        if (refresh == true && mounted) {
          await _model.load();
        }
      },
    ),
  );

  /// Returns true if Vehicles list needs to be reloaded
  Future<bool?> _openVehicleForm({Vehicle? vehicle}) => Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => VehicleFormScreen(repo: widget.repo, clock: widget.clock, vehicle: vehicle),
    ),
  );

  VehicleCard _buildVehicleCard(Vehicle vehicle) => VehicleCard(
    key: GarageScreen.vehicleCardKey(vehicle.id),
    vehicle: vehicle,
    now: widget.clock.now(),
    onAction: (action) => _handleMenuAction(action, vehicle),
  );

  Future<void> _handleMenuAction(VehicleAction action, Vehicle v) async {
    final refresh = await switch (action) {
      .edit => _openVehicleForm(vehicle: v),
      .delete => _deleteVehicle(v),
      .schedules => _editSchedules(v),
    };
    if (refresh == true && mounted) {
      await _model.load();
    }
  }

  Future<bool?> _editSchedules(Vehicle v) async => false;

  Future<bool?> _deleteVehicle(Vehicle v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: GarageScreen.deleteConfirmation,
        title: const Text('Delete vehicle?'),
        content: Text('Delete "${v.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            key: GarageScreen.cancelButton,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: GarageScreen.deleteButton,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    try {
      await widget.repo.deleteVehicle(v.id);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not confirm deletion. Refreshing...')),
          );
      }
    }
    return true;
  }
}
