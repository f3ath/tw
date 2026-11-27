import 'package:app/ui/delete_and_refresh.dart';
import 'package:app/ui/open_and_refresh_on_change.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:shared/model.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/list_state_view.dart';
import 'package:app/ui/garage/vehicle_card.dart';
import 'package:app/ui/schedules/schedule_screen.dart';
import 'package:app/ui/services/service_screen.dart';
import 'package:app/ui/services/service_form_screen.dart';
import 'package:app/ui/operations/operation_screen.dart';
import 'package:app/ui/garage/vehicle_form_screen.dart';
import 'package:shared/time.dart';

class const GarageScreen({
  super.key,
  required final Future<void> Function() onLogout,
  required final String userName,
  final Now now = DateTime.now,
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
  Widget build(BuildContext context) {
    final actions = _GarageActions(
      context: context,
      now: widget.now,
      reload: _model.load,
      delete: _repo.delete,
    );
    return Scaffold(
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
      body: ListStateView<Vehicle>(
        model: _model,
        loadingIndicatorKey: GarageScreen.loadingIndicatorKey,
        errorTextKey: GarageScreen.errorTextKey,
        retryButtonKey: GarageScreen.retryButtonKey,
        emptyTextKey: GarageScreen.emptyTextKey,
        errorMessage: 'Error loading vehicles',
        emptyMessage: 'No vehicles yet',
        itemBuilder: (vehicle) => _buildVehicleCard(vehicle, actions),
        errorMainAxisSize: .max,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: GarageScreen.addButtonKey,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        onPressed: () => actions.openVehicleForm(),
      ),
    );
  }

  VehicleCard _buildVehicleCard(Vehicle vehicle, _GarageActions actions) => VehicleCard(
    key: GarageScreen.vehicleCardKey(vehicle.id),
    vehicle: vehicle,
    asOf: CalendarDate.today(now: widget.now),
    onAction: (action) => actions.handle(action, vehicle),
  );
}

class const _GarageActions({
  required final BuildContext context,
  required final Now now,
  required final Future<void> Function() reload,
  required final Future<void> Function(String) delete,
}) {
  Future<void> openVehicleForm({Vehicle? vehicle}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(now: now, vehicle: vehicle, onCreateConflict: reload),
      ),
    );
    if (refresh == true && context.mounted) await reload();
  }

  Future<void> handle(VehicleAction action, Vehicle vehicle) => switch (action) {
    .edit => openVehicleForm(vehicle: vehicle),
    .delete => _deleteVehicle(vehicle),
    .services => _openServices(vehicle),
    .newService => _openServiceForm(vehicle),
    .schedules => _openSchedules(vehicle),
  };

  Future<void> _deleteVehicle(Vehicle vehicle) => confirmDeleteAndRefresh(
    context: context,
    title: 'Delete vehicle?',
    message: 'Delete "${vehicle.name}"? This cannot be undone.',
    delete: () => delete(vehicle.id),
    refresh: reload,
    errorSnackBarKey: GarageScreen.deleteErrorSnackBarKey,
  );

  Future<void> _openSchedules(Vehicle vehicle) => openAndRefreshOnChange(
    context: context,
    buildScreen: (onChanged) => ScheduleScreen(vehicle: vehicle, onChanged: onChanged),
    refresh: reload,
  );

  Future<void> _openServices(Vehicle vehicle) => openAndRefreshOnChange(
    context: context,
    buildScreen: (onChanged) => ServiceScreen(vehicle: vehicle, onChanged: onChanged),
    refresh: reload,
  );

  Future<void> _openServiceForm(Vehicle vehicle) async {
    final service = await Navigator.of(context).push<Service>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          vehicle: vehicle,
          now: now,
          onViewHistory: () => _openServices(vehicle),
        ),
      ),
    );
    if (service == null || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationScreen(
          vehicleService: VehicleService(vehicle: vehicle, service: service),
        ),
      ),
    );
    if (context.mounted) await reload();
  }
}
