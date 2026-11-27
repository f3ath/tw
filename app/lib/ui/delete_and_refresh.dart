import 'package:app/ui/delete_confirmation_dialog.dart';
import 'package:material_ui/material_ui.dart';

Future<void> confirmDeleteAndRefresh({
  required BuildContext context,
  required String title,
  required String message,
  required Future<void> Function() delete,
  required Future<void> Function() refresh,
  required Key errorSnackBarKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => DeleteConfirmationDialog(
      key: DeleteConfirmationDialog.confirmationKey,
      title: title,
      message: message,
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await deleteAndRefresh(
    context: context,
    delete: delete,
    refresh: refresh,
    errorSnackBarKey: errorSnackBarKey,
  );
}

Future<void> deleteAndRefresh({
  required BuildContext context,
  required Future<void> Function() delete,
  required Future<void> Function() refresh,
  required Key errorSnackBarKey,
}) async {
  try {
    await delete();
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: errorSnackBarKey,
            content: const Text('Could not confirm deletion. Refreshing...'),
          ),
        );
    }
  }
  if (context.mounted) await refresh();
}
