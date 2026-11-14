import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/service_repo.dart';
import 'package:tw_app/ui/services/service_card.dart';
import 'package:tw_app/ui/services/service_view_model.dart';
import 'package:tw_app/ui/services/service_form_screen.dart';

class const ServiceScreen({
  super.key,
  required final Vehicle vehicle,
  required final ServiceRepo repo,
}) extends StatefulWidget {
  static const addButtonKey = ValueKey('services-add-button');
  static const loadingIndicatorKey = ValueKey('services-loading-indicator');
  static const errorTextKey = ValueKey('services-error-text');
  static const emptyTextKey = ValueKey('services-empty-text');
  static const retryButtonKey = ValueKey('services-retry-button');
  static ValueKey<String> serviceKey(String id) => ValueKey('service-$id');

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  late final ServiceViewModel _model;

  @override
  void initState() {
    super.initState();
    _model = ServiceViewModel(repo: widget.repo, vehicleId: widget.vehicle.id);
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
          return const Center(
            child: CircularProgressIndicator(key: ServiceScreen.loadingIndicatorKey),
          );
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              mainAxisSize: .min,
              children: [
                const Text('Error loading services', key: ServiceScreen.errorTextKey),
                FilledButton(
                  key: ServiceScreen.retryButtonKey,
                  onPressed: _model.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (_model.services.isEmpty) {
          return const Center(child: Text('No services yet', key: ServiceScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.services.length,
          itemBuilder: (_, index) => _buildServiceCard(_model.services[index]),
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
      case .edit:
        await _openServiceForm(service: service);
        return;
    }
  }

  Future<void> _openServiceForm({Service? service}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceFormScreen(vehicle: widget.vehicle, repo: widget.repo, service: service),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }
}
