import 'package:app/ui/operations/service_info_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ServiceCard({
  super.key,
  required final Service service,
  required final MileageUnit mileageUnit,
  required final ValueChanged<ServiceAction> onAction,
}) extends StatelessWidget {
  static ValueKey<String> menuKey(String serviceId) => ValueKey('service-menu-$serviceId');

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.top,
        onTap: () => onAction(ServiceAction.operations),
        title: ServiceInfoText(service: service, mileageUnit: mileageUnit),
        trailing: PopupMenuButton<ServiceAction>(
          key: ServiceCard.menuKey(service.id),
          tooltip:
              'Manage service on ${localizations.formatShortDate(service.date.toLocalDateTime())}',
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
        subtitle: service.details.isEmpty && service.operations.isEmpty
            ? null
            : Column(
                crossAxisAlignment: .start,
                children: [
                  if (service.details.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(service.details)),
                  if (service.operations.isNotEmpty) ...[
                    for (final operation in service.operations)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: .start,
                          children: [
                            const Text('•'),
                            const SizedBox(width: 8),
                            Expanded(child: Text(operation.name)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

enum ServiceAction { operations, edit, delete }
