import 'package:shared/model.dart';

abstract interface class ScheduleRepo {
  Future<List<Schedule>> list(String vehicleId);

  Future<void> create(
    String vehicleId, {
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  });

  Future<void> update(
    String scheduleId, {
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    required String details,
  });

  Future<void> delete(String scheduleId);
}
