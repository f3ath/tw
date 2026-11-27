import 'package:app/app/create_conflict.dart';
import 'package:app/app/operation_repo.dart';
import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/api.dart';

class BackendOperationRepo(final TwApiClient _client) implements OperationRepo {
  @override
  Future<List<Operation>> list(String serviceId) => _client.listOperations(serviceId);

  @override
  Future<void> create(
    String serviceId, {
    required String id,
    required String name,
    String details = '',
  }) => _create(serviceId, id: id, name: name, details: details);

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
    required String id,
    required String scheduleId,
    String details = '',
  }) => _create(serviceId, id: id, scheduleId: scheduleId, details: details);

  Future<void> _create(
    String serviceId, {
    required String id,
    String? name,
    String? scheduleId,
    required String details,
  }) async {
    try {
      await _client.createOperation(
        serviceId,
        id: id,
        name: name,
        scheduleId: scheduleId,
        details: details,
      );
    } on RequestFailure catch (error) {
      if (error.rawResponse.httpResponse.statusCode != 409) rethrow;
      throw const CreateConflict();
    }
  }
}
