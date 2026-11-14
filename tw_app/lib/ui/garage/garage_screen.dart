import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/ui/garage/vehicle_delete_dialog.dart';
import 'package:tw_app/app/vehicle_repo.dart';
import 'package:tw_app/app/schedule_repo.dart';
import 'package:tw_app/time/clock.dart';
import 'package:tw_app/ui/garage/garage_view_model.dart';
import 'package:tw_app/ui/garage/vehicle_card.dart';
import 'package:tw_app/ui/schedules/schedule_screen.dart';
import 'package:tw_app/ui/garage/vehicle_form_screen.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  required final VehicleRepo repo,
  required final ScheduleRepo scheduleRepo,
  final Clock clock = const Clock(),
}) extends StatefulWidget {
  static ValueKey<String> vehicleCardKey(String vehicleId) => ValueKey('vehicle-$vehicleId');

  static const userNameTextKey = ValueKey('user-name-text');
  static const logoutButtonKey = ValueKey('logout-button');
  static const loadingIndicatorKey = ValueKey('garage-loading-indicator');
  static const errorTextKey = ValueKey('garage-error-text');
  static const emptyTextKey = ValueKey('garage-empty-text');
  static const deleteErrorSnackBarKey = ValueKey('garage-delete-error-snackbar');
  static const retryButtonKey = ValueKey('retry-button');
  static const addButtonKey = ValueKey('add-button');

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
          return const Center(
            child: CircularProgressIndicator(key: GarageScreen.loadingIndicatorKey),
          );
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              children: [
                Text('Error loading vehicles', key: GarageScreen.errorTextKey),
                FilledButton(
                  key: GarageScreen.retryButtonKey,
                  onPressed: _model.load,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (_model.vehicles.isEmpty) {
          return Center(child: Text('No vehicles yet', key: GarageScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.vehicles.length,
          itemBuilder: (_, index) => _buildVehicleCard(_model.vehicles[index]),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: GarageScreen.addButtonKey,
      icon: const Icon(Icons.add),
      label: const Text('New Vehicle'),
      onPressed: () => _openVehicleForm(),
    ),
  );

  Future<void> _openVehicleForm({Vehicle? vehicle}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(repo: widget.repo, clock: widget.clock, vehicle: vehicle),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }

  VehicleCard _buildVehicleCard(Vehicle vehicle) => VehicleCard(
    key: GarageScreen.vehicleCardKey(vehicle.id),
    vehicle: vehicle,
    now: widget.clock.now(),
    onAction: (action) => _handleMenuAction(action, vehicle),
  );

  Future<void> _handleMenuAction(VehicleAction action, Vehicle v) async {
    switch (action) {
      case .edit:
        await _openVehicleForm(vehicle: v);
        return;
      case .delete:
        final refresh = await _deleteVehicle(v);
        if (refresh == true && mounted) await _model.load();
        return;
      case .schedules:
        await _openSchedules(v);
        return;
    }
  }

  Future<void> _openSchedules(Vehicle vehicle) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScheduleScreen(vehicle: vehicle, repo: widget.scheduleRepo),
    ),
  );

  Future<bool?> _deleteVehicle(Vehicle v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => VehicleDeleteDialog(key: VehicleDeleteDialog.confirmationKey, vehicle: v),
    );
    if (confirmed != true || !mounted) return false;
    try {
      await widget.repo.delete(v.id);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: GarageScreen.deleteErrorSnackBarKey,
              content: Text('Could not confirm deletion. Refreshing...'),
            ),
          );
      }
    }
    return true;
  }
}
