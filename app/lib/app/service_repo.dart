import 'package:shared/model.dart';
import 'package:shared/time.dart';

abstract interface class ServiceRepo {
  Future<List<Service>> list(String vehicleId);

  Future<Service> create(
    String vehicleId, {
    required String id,
    required CalendarDate date,
    required int odometer,
    String details = '',
  });

  Future<void> update(
    String serviceId, {
    required CalendarDate date,
    required int odometer,
    required String details,
  });

  Future<void> delete(String serviceId);
}
