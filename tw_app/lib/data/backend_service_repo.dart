import 'package:shared/api.dart';
import 'package:tw_app/app/service_repo.dart';

class BackendServiceRepo(final TwApiClient _client) implements ServiceRepo {
  @override
  Future<List<Service>> list(String vehicleId) => _client.listServices(vehicleId);
}
