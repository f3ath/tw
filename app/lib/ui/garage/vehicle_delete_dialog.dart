import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const VehicleDeleteDialog({super.key, required final Vehicle vehicle})
    extends StatelessWidget {
  static const confirmationKey = ValueKey('delete-confirmation');
  static const deleteButtonKey = ValueKey('delete-confirmation-delete');
  static const cancelButtonKey = ValueKey('delete-confirmation-cancel');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete vehicle?'),
    content: Text('Delete "${vehicle.name}"? This cannot be undone.'),
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
