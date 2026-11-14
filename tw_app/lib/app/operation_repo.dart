import 'package:shared/model.dart';

abstract interface class OperationRepo {
  Future<List<Operation>> list(String serviceId);

  Future<void> create(String serviceId, {required String name, String details = ''});

  Future<void> createFromSchedule(
    String serviceId, {
    required String scheduleId,
    String details = '',
  });
}
