import 'package:material_ui/material_ui.dart';

class const DeleteConfirmationDialog({
  super.key,
  required final String title,
  required final String message,
}) extends StatelessWidget {
  static const confirmationKey = ValueKey('delete-confirmation');
  static const cancelButtonKey = ValueKey('delete-confirmation-cancel');
  static const deleteButtonKey = ValueKey('delete-confirmation-delete');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
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
