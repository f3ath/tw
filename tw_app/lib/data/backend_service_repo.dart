import 'package:shared/api.dart';
import 'package:tw_app/app/service_repo.dart';

class BackendServiceRepo(final TwApiClient _client) implements ServiceRepo {
  @override
  Future<List<Service>> list(String vehicleId) => _client.listServices(vehicleId);

  @override
  Future<void> create(
    String vehicleId, {
    required DateTime date,
    required int odometer,
    String details = '',
  }) async {
    await _client.createService(vehicleId, date: date, odometer: odometer, details: details);
  }

  @override
  Future<void> update(
    String serviceId, {
    required DateTime date,
    required int odometer,
    required String details,
  }) async {
    await _client.updateService(serviceId, date: date, odometer: odometer, details: details);
  }
}
