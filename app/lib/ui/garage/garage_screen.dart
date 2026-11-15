import 'package:app/ui/delete_and_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:shared/model.dart';
import 'package:app/ui/garage/vehicle_delete_dialog.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/time/clock.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/loading_view.dart';
import 'package:app/ui/error_retry_view.dart';
import 'package:app/ui/garage/vehicle_card.dart';
import 'package:app/ui/schedules/schedule_screen.dart';
import 'package:app/ui/services/service_screen.dart';
import 'package:app/ui/services/service_form_screen.dart';
import 'package:app/ui/operations/operation_screen.dart';
import 'package:app/ui/garage/vehicle_form_screen.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
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
  late final VehicleRepo _repo;
  late final ListViewModel<Vehicle> _model;

  @override
  void initState() {
    super.initState();
    _repo = RepositoryProvider.read(context).vehicleRepo;
    _model = ListViewModel<Vehicle>(fetch: _repo.list);
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
          return const LoadingView(indicatorKey: GarageScreen.loadingIndicatorKey);
        }
        if (_model.hasError) {
          return ErrorRetryView(
            message: 'Error loading vehicles',
            errorTextKey: GarageScreen.errorTextKey,
            retryButtonKey: GarageScreen.retryButtonKey,
            onRetry: _model.load,
            mainAxisSize: .max,
          );
        }
        if (_model.items.isEmpty) {
          return Center(child: Text('No vehicles yet', key: GarageScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.items.length,
          itemBuilder: (_, index) => _buildVehicleCard(_model.items[index]),
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
        builder: (_) => VehicleFormScreen(clock: widget.clock, vehicle: vehicle),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }

  VehicleCard _buildVehicleCard(Vehicle vehicle) => VehicleCard(
    key: GarageScreen.vehicleCardKey(vehicle.id),
    vehicle: vehicle,
    now: widget.clock.now(),
    onAction: (action) => _handleVehicleAction(action, vehicle),
  );

  Future<void> _handleVehicleAction(VehicleAction action, Vehicle v) async {
    switch (action) {
      case .edit:
        await _openVehicleForm(vehicle: v);
        return;
      case .delete:
        await _deleteVehicle(v);
        return;
      case .services:
        await _openServices(v);
        return;
      case .newService:
        await _openServiceForm(v);
        return;
      case .schedules:
        await _openSchedules(v);
        return;
    }
  }

  Future<void> _openSchedules(Vehicle vehicle) =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => ScheduleScreen(vehicle: vehicle)));

  Future<void> _openServices(Vehicle vehicle) =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => ServiceScreen(vehicle: vehicle)));

  Future<void> _openServiceForm(Vehicle vehicle) async {
    final service = await Navigator.of(context).push<Service>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(vehicle: vehicle, clock: widget.clock),
      ),
    );
    if (service == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationScreen(
          vehicleService: VehicleService(vehicle: vehicle, service: service),
        ),
      ),
    );
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => VehicleDeleteDialog(key: VehicleDeleteDialog.confirmationKey, vehicle: v),
    );
    if (confirmed != true || !mounted) return;
    await deleteAndRefresh(
      context: context,
      delete: () => _repo.delete(v.id),
      refresh: _model.load,
      errorSnackBarKey: GarageScreen.deleteErrorSnackBarKey,
    );
  }
}
