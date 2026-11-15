import 'package:material_ui/material_ui.dart';

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
