import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/api.dart';
import 'package:app/app/schedule_repo.dart';
import 'package:app/app/create_conflict.dart';

class BackendScheduleRepo(final TwApiClient _client) implements ScheduleRepo {
  @override
  Future<List<Schedule>> list(String vehicleId) => _client.listSchedules(vehicleId);

  @override
  Future<void> create(
    String vehicleId, {
    required String id,
    required String name,
    int? intervalDistance,
    int? intervalMonths,
    String details = '',
  }) async {
    try {
      await _client.createSchedule(
        vehicleId,
        id: id,
        name: name,
        intervalDistance: intervalDistance,
        intervalMonths: intervalMonths,
        details: details,
      );
    } on RequestFailure catch (error) {
      if (error.rawResponse.httpResponse.statusCode != 409) rethrow;
      throw const CreateConflict();
    }
  }

  @override
  Future<void> update(
    String scheduleId, {
    required String name,
    required int? intervalDistance,
    required int? intervalMonths,
    required String details,
  }) async {
    await _client.updateSchedule(
      scheduleId,
      name: name,
      intervalDistance: intervalDistance,
      intervalMonths: intervalMonths,
      details: details,
    );
  }

  @override
  Future<void> delete(String scheduleId) => _client.deleteSchedule(scheduleId);
}
