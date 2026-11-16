import 'package:app/ui/delete_and_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/app/repository_provider.dart';
import 'package:app/app/vehicle_service.dart';
import 'package:shared/model.dart';
import 'package:app/app/operation_repo.dart';
import 'package:app/ui/operations/operation_card.dart';
import 'package:app/ui/operations/operation_delete_dialog.dart';
import 'package:app/ui/operations/operation_form_screen.dart';
import 'package:app/ui/list_view_model.dart';
import 'package:app/ui/loading_view.dart';
import 'package:app/ui/error_retry_view.dart';

class const OperationScreen({super.key, required final VehicleService vehicleService})
    extends StatefulWidget {
  static const vehicleNameTextKey = ValueKey('operations-vehicle-name');
  static const serviceDateTextKey = ValueKey('operations-service-date');
  static const loadingIndicatorKey = ValueKey('operations-loading-indicator');
  static const errorTextKey = ValueKey('operations-error-text');
  static const emptyTextKey = ValueKey('operations-empty-text');
  static const retryButtonKey = ValueKey('operations-retry-button');
  static const deleteErrorSnackBarKey = ValueKey('operation-delete-error-snackbar');
  static const addButtonKey = ValueKey('operations-add-button');
  static ValueKey<String> operationKey(String id) => ValueKey('operation-$id');

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  late final OperationRepo _repo;
  late final ListViewModel<Operation> _model;

  @override
  void initState() {
    super.initState();
    _repo = RepositoryProvider.read(context).operationRepo;
    _model = ListViewModel<Operation>(fetch: () => _repo.list(widget.vehicleService.service.id));
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
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  widget.vehicleService.vehicle.name,
                  key: OperationScreen.vehicleNameTextKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  MaterialLocalizations.of(context)
                      .formatShortDate(widget.vehicleService.service.date),
                  key: OperationScreen.serviceDateTextKey,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: _model,
      builder: (_, _) {
        if (_model.isLoading) {
          return const LoadingView(indicatorKey: OperationScreen.loadingIndicatorKey);
        }
        if (_model.hasError) {
          return ErrorRetryView(
            message: 'Error loading operations',
            errorTextKey: OperationScreen.errorTextKey,
            retryButtonKey: OperationScreen.retryButtonKey,
            onRetry: _model.load,
          );
        }
        if (_model.items.isEmpty) {
          return const Center(child: Text('No operations yet', key: OperationScreen.emptyTextKey));
        }
        return ListView.builder(
          itemCount: _model.items.length,
          itemBuilder: (_, index) => _buildOperationCard(_model.items[index]),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: OperationScreen.addButtonKey,
      icon: const Icon(Icons.add),
      label: const Text('New Operation'),
      onPressed: () => _openOperationForm(),
    ),
  );

  OperationCard _buildOperationCard(Operation operation) => OperationCard(
    key: OperationScreen.operationKey(operation.id),
    operation: operation,
    onAction: (action) {
      switch (action) {
        case OperationAction.edit:
          _openOperationForm(operation: operation);
        case OperationAction.delete:
          _deleteOperation(operation);
      }
    },
  );

  Future<void> _deleteOperation(Operation operation) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => OperationDeleteDialog(
            key: OperationDeleteDialog.confirmationKey,
            operation: operation,
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await deleteAndRefresh(
      context: context,
      delete: () => _repo.delete(operation.id),
      refresh: _model.load,
      errorSnackBarKey: OperationScreen.deleteErrorSnackBarKey,
    );
  }

  Future<void> _openOperationForm({Operation? operation}) async {
    final refresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            OperationFormScreen(vehicleService: widget.vehicleService, operation: operation),
      ),
    );
    if (refresh == true && mounted) await _model.load();
  }
}
