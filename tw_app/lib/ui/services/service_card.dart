import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ServiceCard({
  super.key,
  required final Service service,
  required final DistanceUnit distanceUnit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(localizations.formatShortDate(service.date)),
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
