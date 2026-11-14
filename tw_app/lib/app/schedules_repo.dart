import 'package:shared/model.dart';

abstract interface class SchedulesRepo {
  Future<List<Schedule>> list(String vehicleId);
}
