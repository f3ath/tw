import 'package:json_api/client.dart' show RequestFailure;
import 'package:shared/api.dart';
import 'package:shared/time.dart';
import 'package:app/app/vehicle_repo.dart';
import 'package:app/app/create_conflict.dart';

class BackendVehicleRepo(final TwApiClient _client) implements VehicleRepo {
  @override
  Future<List<Vehicle>> list() => _client.listVehicles();

  @override
  Future<void> create({
    required String id,
    required String name,
    required CalendarDate manufactureDate,
    required MileageUnit mileageUnit,
  }) async {
    try {
      await _client.createVehicle(
        id: id,
        name: name,
        manufactureDate: manufactureDate,
        mileageUnit: mileageUnit,
      );
    } on RequestFailure catch (error) {
      if (error.rawResponse.httpResponse.statusCode != 409) rethrow;
      throw const CreateConflict();
    }
  }

  @override
  Future<void> update(
    String id, {
    required String name,
    required CalendarDate manufactureDate,
    MileageUnit? mileageUnit,
  }) async {
    await _client.updateVehicle(
      id,
      name: name,
      manufactureDate: manufactureDate,
      mileageUnit: mileageUnit,
    );
  }

  @override
  Future<void> delete(String id) => _client.deleteVehicle(id);
}
