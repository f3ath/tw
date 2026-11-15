import 'package:shared/model.dart';

final class VehicleSchedule({required final Vehicle vehicle, required final Schedule schedule}) {
  this {
    if (schedule.vehicleId != vehicle.id) {
      throw ArgumentError.value(
        schedule,
        'schedule',
        'Schedule must belong to vehicle ${vehicle.id}',
      );
    }
  }
}
