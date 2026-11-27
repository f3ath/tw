import 'package:shared/time.dart';

import 'operation.dart';

class const Service(
  final String id, {
  required final String vehicleId,
  required final CalendarDate date,
  required final int odometer,
  required final String details,
  final List<Operation> operations = const [],
});
