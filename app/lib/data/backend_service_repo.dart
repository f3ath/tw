import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:app/app/service_repo.dart';
import 'package:app/app/create_conflict.dart';
import 'package:json_api/client.dart' show RequestFailure;

class BackendServiceRepo(final TwApiClient _client) implements ServiceRepo {
  @override
  Future<List<Service>> list(String vehicleId) =>
      _client.listServices(vehicleId, includeOperations: true);

  @override
  Future<Service> create(
    String vehicleId, {
    required String id,
    required CalendarDate date,
    required int odometer,
    String details = '',
  }) async {
    try {
      return await _client.createService(
        vehicleId,
        id: id,
        date: date,
        odometer: odometer,
        details: details,
      );
    } on RequestFailure catch (error) {
      if (error.rawResponse.httpResponse.statusCode != 409) rethrow;
      throw const CreateConflict();
    }
  }

  @override
  Future<void> update(
    String serviceId, {
    required CalendarDate date,
    required int odometer,
    required String details,
  }) async {
    await _client.updateService(serviceId, date: date, odometer: odometer, details: details);
  }

  @override
  Future<void> delete(String serviceId) => _client.deleteService(serviceId);
}
