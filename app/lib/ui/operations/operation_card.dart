import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const OperationCard({
  super.key,
  required final Operation operation,
  required final ValueChanged<OperationAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String id) => ValueKey('operation-menu-$id');

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(operation.name),
      trailing: PopupMenuButton<OperationAction>(
        key: OperationCard.menuKey(operation.id),
        tooltip: 'Manage ${operation.name}',
        icon: const Icon(Icons.more_vert),
        onSelected: onAction,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: OperationAction.edit,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Edit')),
              ],
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: OperationAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
      subtitle: operation.details.isEmpty ? null : Text(operation.details),
    ),
  );
}

enum OperationAction { edit, delete }
