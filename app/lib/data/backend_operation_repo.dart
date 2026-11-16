import 'package:shared/api.dart';
import 'package:app/app/operation_repo.dart';

class BackendOperationRepo(final TwApiClient _client) implements OperationRepo {
  @override
  Future<List<Operation>> list(String serviceId) => _client.listOperations(serviceId);

  @override
  Future<void> create(String serviceId, {required String name, String details = ''}) async {
    await _client.createOperation(serviceId, name: name, details: details);
  }

  @override
  Future<void> update(
    String operationId, {
    required String name,
    required String details,
    required String? scheduleId,
  }) async {
    await _client.updateOperation(
      operationId,
      name: name,
      details: details,
      scheduleId: scheduleId,
    );
  }

  @override
  Future<void> delete(String operationId) => _client.deleteOperation(operationId);

  @override
  Future<void> createFromSchedule(
    String serviceId, {
    required String scheduleId,
    String details = '',
  }) async {
    await _client.createOperation(serviceId, scheduleId: scheduleId, details: details);
  }
}
