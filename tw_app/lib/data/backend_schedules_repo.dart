import 'package:shared/api.dart';
import 'package:tw_app/app/schedules_repo.dart';

class BackendSchedulesRepo(final TwApiClient _client) implements SchedulesRepo {
  @override
  Future<List<Schedule>> list(String vehicleId) => _client.listSchedules(vehicleId);
}
