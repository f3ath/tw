import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const OperationDeleteDialog({super.key, required final Operation operation})
    extends StatelessWidget {
  static const confirmationKey = ValueKey('operation-delete-confirmation');
  static const deleteButtonKey = ValueKey('operation-delete-confirmation-delete');
  static const cancelButtonKey = ValueKey('operation-delete-confirmation-cancel');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete operation?'),
    content: Text('Delete "${operation.name}"? This cannot be undone.'),
    actions: [
      TextButton(
        key: cancelButtonKey,
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: deleteButtonKey,
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Delete'),
      ),
    ],
  );
}
