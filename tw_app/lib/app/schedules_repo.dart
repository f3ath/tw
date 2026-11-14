import 'package:shared/model.dart';

abstract interface class SchedulesRepo {
  Future<List<Schedule>> list(String vehicleId);

  Future<void> create(
    String vehicleId, {
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  });
}
