import 'package:shared/src/model/mileage_unit.dart';
import 'package:shared/time.dart';

class const Vehicle(
  final String id, {
  required final String name,
  required final CalendarDate manufactureDate,
  required final MileageUnit mileageUnit,
  final Odometer? odometer,
});

final class const Odometer({required final CalendarDate date, required final int value});
