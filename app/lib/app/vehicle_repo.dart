import 'package:shared/model.dart';
import 'package:shared/time.dart';

abstract interface class VehicleRepo {
  Future<List<Vehicle>> list();

  Future<void> create({
    required String id,
    required String name,
    required CalendarDate manufactureDate,
    required MileageUnit mileageUnit,
  });

  Future<void> update(
    String id, {
    required String name,
    required CalendarDate manufactureDate,
    MileageUnit? mileageUnit,
  });

  Future<void> delete(String id);
}
