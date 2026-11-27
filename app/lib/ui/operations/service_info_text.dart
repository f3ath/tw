import 'package:material_ui/material_ui.dart';
import 'package:shared/model.dart';

class const ServiceInfoText({
  super.key,
  required final Service service,
  required final MileageUnit mileageUnit,
  final TextStyle? style,
}) extends StatelessWidget {
  static const serviceInfoTextKey = ValueKey('operations-service-date');

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(service.date.toLocalDateTime());
    final odometer = localizations.formatDecimal(service.odometer);

    return Text(
      '$date at $odometer ${mileageUnit.name}',
      key: serviceInfoTextKey,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
