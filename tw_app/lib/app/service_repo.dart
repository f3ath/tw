import 'package:shared/model.dart';

abstract interface class ServiceRepo {
  Future<List<Service>> list(String vehicleId);

  Future<void> create(
    String vehicleId, {
    required DateTime date,
    required int odometer,
    String details = '',
  });

  Future<void> update(
    String serviceId, {
    required DateTime date,
    required int odometer,
    required String details,
  });

  Future<void> delete(String serviceId);
}
