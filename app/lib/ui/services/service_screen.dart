import 'package:app/ui/delete_and_refresh.dart';
import 'package:app/ui/open_and_refresh_on_change.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/ui/list_state_view.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/operations/operation_screen.dart';
import 'package:app/ui/services/service_card.dart';
import 'package:app/ui/services/service_form_screen.dart';

class const ServiceScreen({
  super.key,
  required final Vehicle vehicle,
  final VoidCallback? onChanged,
}) extends StatefulWidget {
  static const addButtonKey = ValueKey('services-add-button');
  static const loadingIndicatorKey = ValueKey('services-loading-indicator');
  static const errorTextKey = ValueKey('services-error-text');
  static const emptyTextKey = ValueKey('services-empty-text');
  static const retryButtonKey = ValueKey('services-retry-button');
  static const deleteErrorSnackBarKey = ValueKey('service-delete-error-snackbar');

  static ValueKey<String> serviceKey(String id) => ValueKey('service-$id');

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  late final ServiceRepo _repo;
  late final ListViewModel<Service> _model;

  @override
  void initState() {
    super.initState();
    _repo = RepositoryProvider.read(context).serviceRepo;
    _model = ListViewModel<Service>(fetch: () => _repo.list(widget.vehicle.id));
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _ServiceActions(
      context: context,
      vehicle: widget.vehicle,
      delete: _repo.delete,
      reload: _model.load,
      onChanged: widget.onChanged,
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.build_outlined, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.vehicle.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListStateView<Service>(
        model: _model,
        loadingIndicatorKey: ServiceScreen.loadingIndicatorKey,
        errorTextKey: ServiceScreen.errorTextKey,
        retryButtonKey: ServiceScreen.retryButtonKey,
        emptyTextKey: ServiceScreen.emptyTextKey,
        errorMessage: 'Error loading services',
        emptyMessage: 'No services yet',
        itemBuilder: (service) => _buildServiceCard(service, actions),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: ServiceScreen.addButtonKey,
        icon: const Icon(Icons.add),
        label: const Text('Log Service'),
        onPressed: () => actions.openForm(),
      ),
    );
  }

  ServiceCard _buildServiceCard(Service service, _ServiceActions actions) => ServiceCard(
    key: ServiceScreen.serviceKey(service.id),
    service: service,
    mileageUnit: widget.vehicle.mileageUnit,
    onAction: (action) => actions.handle(action, service),
  );
}

class const _ServiceActions({
  required final BuildContext context,
  required final Vehicle vehicle,
  required final Future<void> Function(String) delete,
  required final Future<void> Function() reload,
  required final VoidCallback? onChanged,
}) {
  Future<void> handle(ServiceAction action, Service service) => switch (action) {
    .operations => _openOperations(service),
    .edit => openForm(service: service),
    .delete => _deleteService(service),
  };

  Future<void> _openOperations(Service service) => openAndRefreshOnChange(
    context: context,
    buildScreen: (onOperationsChanged) => OperationScreen(
      vehicleService: VehicleService(vehicle: vehicle, service: service),
      onOperationsChanged: onOperationsChanged,
    ),
    refresh: reload,
    onChanged: onChanged,
  );

  Future<void> _deleteService(Service service) => confirmDeleteAndRefresh(
    context: context,
    title: 'Delete service?',
    message: 'Delete this service? This cannot be undone.',
    delete: () => delete(service.id),
    refresh: _reloadAfterChange,
    errorSnackBarKey: ServiceScreen.deleteErrorSnackBarKey,
  );

  Future<void> openForm({Service? service}) async {
    final savedService = await Navigator.of(context).push<Service>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
          vehicle: vehicle,
          service: service,
          onCreateConflict: _reloadAfterChange,
        ),
      ),
    );
    if (savedService != null && context.mounted) await _reloadAfterChange();
  }

  Future<void> _reloadAfterChange() {
    onChanged?.call();
    return reload();
  }
}
