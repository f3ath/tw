import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';
import 'package:tw_app/app/operation_repo.dart';
import 'package:tw_app/ui/operations/operation_card.dart';
import 'package:tw_app/ui/list_view_model.dart';

class const OperationScreen({
  super.key,
  required final Service service,
  required final OperationRepo repo,
}) extends StatefulWidget {
  static const loadingIndicatorKey = ValueKey('operations-loading-indicator');
  static const errorTextKey = ValueKey('operations-error-text');
  static const emptyTextKey = ValueKey('operations-empty-text');
  static const retryButtonKey = ValueKey('operations-retry-button');
  static ValueKey<String> operationKey(String id) => ValueKey('operation-$id');

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  late final ListViewModel<Operation> _model;

  @override
  void initState() {
    super.initState();
    _model = ListViewModel<Operation>(fetch: () => widget.repo.list(widget.service.id));
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
          const Icon(Icons.checklist_outlined, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Operations · ${MaterialLocalizations.of(context).formatShortDate(widget.service.date)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: _model,
      builder: (_, _) {
        if (_model.isLoading) {
          return const Center(
            child: CircularProgressIndicator(key: OperationScreen.loadingIndicatorKey),
          );
        }
        if (_model.hasError) {
          return Center(
            child: Column(
              mainAxisSize: .min,
              children: [
                const Text('Error loading operations', key: OperationScreen.errorTextKey),
                FilledButton(
                  key: OperationScreen.retryButtonKey,
                  onPressed: _model.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
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
  );

  OperationCard _buildOperationCard(Operation operation) =>
      OperationCard(key: OperationScreen.operationKey(operation.id), operation: operation);
}
