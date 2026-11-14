import 'package:shared/api.dart';
import 'package:tw_app/app/operation_repo.dart';

class BackendOperationRepo(final TwApiClient _client) implements OperationRepo {
  @override
  Future<List<Operation>> list(String serviceId) => _client.listOperations(serviceId);

  @override
  Future<void> create(String serviceId, {required String name, String details = ''}) async {
    await _client.createOperation(serviceId, name: name, details: details);
  }
}
