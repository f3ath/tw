import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ServiceCard({
  super.key,
  required final Service service,
  required final DistanceUnit distanceUnit,
  required final ValueChanged<ServiceAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String serviceId) => ValueKey('service-menu-$serviceId');

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(localizations.formatShortDate(service.date)),
        trailing: PopupMenuButton<ServiceAction>(
          key: ServiceCard.menuKey(service.id),
          tooltip: 'Manage service on ${localizations.formatShortDate(service.date)}',
          icon: const Icon(Icons.more_vert),
          onSelected: onAction,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: ServiceAction.edit,
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
              value: ServiceAction.delete,
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
        subtitle: Column(
          crossAxisAlignment: .start,
          children: [
            Text('${localizations.formatDecimal(service.odometer)} ${distanceUnit.name}'),
            if (service.details.isNotEmpty) Text(service.details),
          ],
        ),
      ),
    );
  }
}

enum ServiceAction { edit, delete }
