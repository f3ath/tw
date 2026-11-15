import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ServiceDeleteDialog({
  super.key,
  required final Service service,
  required final DistanceUnit distanceUnit,
}) extends StatelessWidget {
  static const confirmationKey = ValueKey('service-delete-confirmation');
  static const deleteButtonKey = ValueKey('service-delete-confirmation-delete');
  static const cancelButtonKey = ValueKey('service-delete-confirmation-cancel');

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(service.date);
    final odometer = localizations.formatDecimal(service.odometer);
    return AlertDialog(
      title: const Text('Delete service?'),
      content: Text(
        'Delete the service on $date at $odometer ${distanceUnit.name}? This cannot be undone.',
      ),
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
}
