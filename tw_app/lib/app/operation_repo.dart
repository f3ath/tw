import 'package:shared/model.dart';

abstract interface class OperationRepo {
  Future<List<Operation>> list(String serviceId);

  Future<void> create(String serviceId, {required String name, String details = ''});

  Future<void> update(
    String operationId, {
    required String name,
    required String details,
    required String? scheduleId,
  });

  Future<void> delete(String operationId);

  Future<void> createFromSchedule(
    String serviceId, {
    required String scheduleId,
    String details = '',
  });
}
