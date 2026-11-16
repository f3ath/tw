import 'package:app/ui/delete_and_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/ui/error_retry_view.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/loading_view.dart';
import 'package:app/ui/operations/operation_screen.dart';
import 'package:app/ui/services/service_card.dart';
import 'package:app/ui/services/service_delete_dialog.dart';
import 'package:app/ui/services/service_form_screen.dart';

class const ServiceScreen({super.key, required final Vehicle vehicle}) extends StatefulWidget {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const Icon(Icons.build_outlined, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.vehicle.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: _model,
      builder: (_, _) {
        if (_model.isLoading) {
          return const LoadingView(indicatorKey: ServiceScreen.loadingIndicatorKey);
        }
        if (_model.hasError) {
          return ErrorRetryView(
            message: 'Error loading services',
            errorTextKey: ServiceScreen.errorTextKey,
            retryButtonKey: ServiceScreen.retryButtonKey,
            onRetry: _model.load,
          );
        }
        if (_model.items.isEmpty) {
          return const Center(child: Text('No services yet', key: ServiceScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.items.length,
          itemBuilder: (_, index) => _buildServiceCard(_model.items[index]),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: ServiceScreen.addButtonKey,
      icon: const Icon(Icons.add),
      label: const Text('New Service'),
      onPressed: () => _openServiceForm(),
    ),
  );

  ServiceCard _buildServiceCard(Service service) => ServiceCard(
    key: ServiceScreen.serviceKey(service.id),
    service: service,
    distanceUnit: widget.vehicle.distanceUnit,
    onAction: (action) => _handleServiceAction(action, service),
  );

  Future<void> _handleServiceAction(ServiceAction action, Service service) async {
    switch (action) {
      case .operations:
        await _openOperations(service);
        return;
      case .edit:
        await _openServiceForm(service: service);
        return;
      case .delete:
        await _deleteService(service);
        return;
    }
  }

  Future<void> _openOperations(Service service) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OperationScreen(
        vehicleService: VehicleService(vehicle: widget.vehicle, service: service),
      ),
    ),
  );

  Future<void> _deleteService(Service service) async {
    final confirmed = await _confirmServiceDeletion(service);
    if (!confirmed || !mounted) return;
    await deleteAndRefresh(
      context: context,
      delete: () => _repo.delete(service.id),
      refresh: _model.load,
      errorSnackBarKey: ServiceScreen.deleteErrorSnackBarKey,
    );
  }

  Future<bool> _confirmServiceDeletion(Service service) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => ServiceDeleteDialog(
          key: ServiceDeleteDialog.confirmationKey,
          service: service,
          distanceUnit: widget.vehicle.distanceUnit,
        ),
      ) ??
      false;

  Future<void> _openServiceForm({Service? service}) async {
    final savedService = await Navigator.of(context).push<Service>(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(vehicle: widget.vehicle, service: service),
      ),
    );
    if (savedService != null && mounted) await _model.load();
  }
}
