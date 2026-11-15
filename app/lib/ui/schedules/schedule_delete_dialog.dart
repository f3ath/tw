import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ScheduleDeleteDialog({super.key, required final Schedule schedule})
    extends StatelessWidget {
  static const confirmationKey = ValueKey('schedule-delete-confirmation');
  static const deleteButtonKey = ValueKey('schedule-delete-confirmation-delete');
  static const cancelButtonKey = ValueKey('schedule-delete-confirmation-cancel');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete schedule?'),
    content: Text('Delete "${schedule.name}"? This cannot be undone.'),
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
